function New-GuideSiteDiscovery {
    [CmdletBinding()]
    param([string]$WorkspaceRoot,[string]$SourcePath,[string[]]$ConfigFiles,[string]$Target,[string]$OutputPath)
    $source=Resolve-GuideWorkspacePath $WorkspaceRoot $SourcePath
    $configuration=(Get-GuideHugoConfiguration -SourcePath $source -ConfigFiles $ConfigFiles -Target $Target).Configuration
    $default=[string]$configuration.defaultcontentlanguage
    $languages=@($configuration.languages.Keys|Where-Object {$configuration.languages[$_].disabled -ne $true})
    $probe=Join-Path $WorkspaceRoot "$OutputPath/discovery-probe"
    New-Item "$probe/layouts" -ItemType Directory -Force|Out-Null
    Copy-Item "$PSScriptRoot/home.html" "$probe/layouts/home.html"
    $overlay=@{disableKinds=@('RSS','sitemap','robotsTXT','404');outputs=@{home=@('HTML')};minify=@{minifyOutput=$false}}
    $overlay|ConvertTo-Json -Depth 10|Set-Content "$probe/overlay.json"
    $lines=@(& hugo --source $source --config (($ConfigFiles+@("$probe/overlay.json"))-join ',') --environment $Target --layoutDir "$probe/layouts" --destination "$probe/site" 2>&1)
    if($LASTEXITCODE -ne 0){throw "Hugo discovery failed: $($lines -join '`n')"}
    $recordFile=Get-ChildItem "$probe/site" -Filter index.html -Recurse -File|Where-Object {([IO.File]::ReadAllText($_.FullName)).TrimStart().StartsWith('{')}|Select-Object -First 1
    if(-not $recordFile){throw 'Hugo did not produce the source inventory. Check the site home output configuration.'}
    $observed=Get-Content $recordFile.FullName -Raw|ConvertFrom-Json -AsHashtable
    $observed|ConvertTo-Json -Depth 30|Set-Content (Join-Path $WorkspaceRoot "$OutputPath/discovered-pages.json")
    $content=Join-Path $source $(if($configuration.contentdir){$configuration.contentdir}else{'content'})
    if([IO.Path]::IsPathRooted([string]$configuration.contentdir)){$content=$configuration.contentdir}
    function ArtifactRoute($url){
        $base=[uri]$configuration.baseurl
        $prefix=if($base.IsAbsoluteUri){$base.AbsolutePath.TrimEnd('/')}else{([string]$configuration.baseurl).TrimEnd('/')}
        if($prefix -and $url.StartsWith($prefix+'/',[StringComparison]::Ordinal)){return $url.Substring($prefix.Length)}
        return $url
    }
    function Relative($path){[IO.Path]::GetRelativePath($WorkspaceRoot,$path).Replace('\','/')}
    function Language($name){if($name -match '^(?:_?index)\.([A-Za-z0-9-]+)\.md$'){return $Matches[1]};return $default}
    $requiredFiles=[Collections.Generic.List[string]]::new()
    $guides=@(foreach($rootFile in Get-ChildItem $content -Filter _index.md -Recurse -File){
        $rootDocument=Read-GuideDocument $rootFile.FullName
        if($rootDocument.Metadata['type'] -ne 'guide' -or $rootDocument.Metadata['layout'] -ne 'root'){continue}
        $directory=$rootFile.DirectoryName
        $editions=@(foreach($editionDirectory in Get-ChildItem $directory -Directory){
            $base=Join-Path $editionDirectory.FullName 'index.md'
            if(-not (Test-Path $base)){continue}
            $document=Read-GuideDocument $base
            if($document.Metadata['layout'] -in @('translations','history','root','details')){continue}
            if($document.Metadata['type'] -ne 'guide' -and -not $document.Metadata.Contains('version')){continue}
            $pdfs=@(Get-ChildItem $editionDirectory.FullName -Filter '*.pdf' -Recurse -File)
            $editionLanguages=@(@(Get-ChildItem $editionDirectory.FullName -Filter 'index*.md' -File|ForEach-Object {Language $_.Name})+@($pdfs|ForEach-Object {if($_.Name -match '\.([A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*)\.pdf$'){$Matches[1]}})|Sort-Object -Unique)
            $translations=@(foreach($language in $editionLanguages){
                $name=if($language -eq $default){'index.md'}else{"index.$language.md"}
                $file=Join-Path $editionDirectory.FullName $name
                $body=if(Test-Path $file){(Read-GuideDocument $file).Body}else{''}
                $downloads=@(foreach($pdf in $pdfs){
                    $pdfLanguage=if($pdf.Name -match '\.([A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*)\.pdf$'){$Matches[1]}else{$default}
                    if($pdfLanguage -ne $language){continue}
                    $relative=[IO.Path]::GetRelativePath($editionDirectory.FullName,$pdf.FullName).Replace('\','/')
                    $urls=@($observed.pages|Where-Object {$_.file.Replace('\','/') -like "$([IO.Path]::GetRelativePath($content,$editionDirectory.FullName).Replace('\','/'))/index*"}|ForEach-Object resources|Where-Object {$_.name -eq $relative -or $_.name.EndsWith('/'+$relative,[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object {(ArtifactRoute $_.url).TrimStart('/')}|Sort-Object -Unique)
                    $download=@{path=$relative;handling='supplied'}
                    if($urls.Count){$download.publishedPaths=$urls}
                    $download
                })
                $intent=if(-not [string]::IsNullOrWhiteSpace($body)){'web'}elseif($downloads.Count){'pdf-only'}elseif($language -eq $default){'web'}else{'fallback'}
                $entry=@{language=$language;intent=$intent;downloads=$downloads}
                if($intent -eq 'fallback'){$entry.fallbackLanguage=$default}
                $entry
            })
            @{id=$(if($document.Metadata.Contains('version')){[string]$document.Metadata.version}else{$editionDirectory.Name});path=$editionDirectory.Name;sourceLanguage=$default;translations=$translations}
        })
        if(-not $editions.Count){continue}
        $guideLanguages=@($editions.translations.language|Where-Object {$_ -in $languages}|Sort-Object -Unique)
        foreach($language in $guideLanguages){
            $suffix=if($language -eq $default){''}else{".$language"}
            foreach($relative in @("_index$suffix.md","history/index$suffix.md","translations/index$suffix.md")){$requiredFiles.Add((Relative (Join-Path $directory $relative)))}
        }
        @{id=([IO.Path]::GetRelativePath($content,$directory).Replace('\','/'));contentRoot=(Relative $directory);relationship=@{kind='independent'};protectSource=$false;editions=$editions}
    })
    if(-not $guides.Count){throw 'No guides were found. Expected guide roots with type: guide, layout: root, and edition bundles with version metadata.'}
    $aliases=@(foreach($file in Get-ChildItem $content -Filter '*.md' -Recurse -File){
        $document=Read-GuideDocument $file.FullName
        $legacy=@($document.Metadata['aliases']|Where-Object {$_ -match '^/(?:[A-Za-z0-9-]+/)?(?:download|downloads|translationsdirectory)/?$'})
        if($legacy.Count){
            $language=Language $file.Name
            $prefix=if($language -eq $default -and -not $configuration.defaultcontentlanguageinsubdir){''}else{"$($language.ToLowerInvariant())/"}
            @{source=(Relative $file.FullName);language=$language;aliases=@($legacy|ForEach-Object {$_.TrimEnd('/')+'/'});targets=@($legacy|ForEach-Object {$prefix+$_.Trim('/')+'/index.html'})}
        }
    })
    $hasMin=$configuration.languages.Contains('min')
    $environments=@(foreach($ring in @('canary','preview','production')){
        $config=Join-Path $source "hugo.$ring.yaml"
        if(-not (Test-Path $config)){continue}
        $effective=(Get-GuideHugoConfiguration -SourcePath $source -ConfigFiles @('hugo.yaml',"hugo.$ring.yaml",$ConfigFiles[-1]) -Target $ring).Configuration
        if($effective.languages.Contains('min')){$hasMin=$true}
        @{name=$ring;excludedLanguages=@($effective.languages.Keys|Where-Object {$effective.languages[$_].disabled -eq $true});excludedGuides=@()}
    })
    $routes=@($observed.pages|ForEach-Object formats|Where-Object name -eq 'HTML'|ForEach-Object {ArtifactRoute $_.url}|Sort-Object -Unique)
    # Alias pages are not members of Hugo .Pages; require their generated routes explicitly.
    foreach($guide in $guides){
        $guideRoute=[IO.Path]::GetRelativePath($content,(Join-Path $WorkspaceRoot $guide.contentRoot)).Replace('\','/').ToLowerInvariant()
        foreach($language in @($guide.editions.translations.language|Where-Object {$_ -in $languages}|Sort-Object -Unique)){
            $suffix=if($language -eq $default){''}else{".$language"}
            $hasAlias=@($guide.editions|Where-Object {
                $file=Join-Path $WorkspaceRoot "$($guide.contentRoot)/$($_.path)/index$suffix.md"
                (Test-Path $file) -and @((Read-GuideDocument $file).Metadata['aliases']|Where-Object {([string]$_).TrimEnd('/') -ceq "/$guideRoute/latest"}).Count
            }).Count
            if($hasAlias){
                $prefix=if($language -eq $default -and -not $configuration.defaultcontentlanguageinsubdir){''}else{"$($language.ToLowerInvariant())/"}
                $routes+= "/$prefix$guideRoute/latest/"
            }
        }
    }
    $inventory=@{schemaVersion=1;siteId=(Split-Path $WorkspaceRoot -Leaf);wrapper=@{sourcePath=$SourcePath;requiredRoutes=$routes;requiredFiles=@($requiredFiles);requiredI18nKeys=@();integrationPoints=@();legacyAliases=$aliases};guides=$guides;publication=@{environments=$environments;permanentExclusions=@(if($hasMin){@{environment='production';subject='language';id='min';reason='Minionese must never be published to production.'}})};protectedPaths=@()}
    return $inventory
}
