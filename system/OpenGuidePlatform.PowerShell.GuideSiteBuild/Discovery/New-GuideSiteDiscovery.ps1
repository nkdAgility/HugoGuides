function New-GuideSiteDiscovery {
    [CmdletBinding()]
    param([string]$WorkspaceRoot,[string]$SourcePath,[string[]]$ConfigFiles,[string]$Target,[string]$OutputPath)
    $source=Resolve-GuideWorkspacePath $WorkspaceRoot $SourcePath
    $configuration=(Get-GuideHugoConfiguration -SourcePath $source -ConfigFiles $ConfigFiles -Target $Target).Configuration
    $default=[string]$configuration.defaultcontentlanguage
    $languages=@($configuration.languages.Keys|Where-Object {$configuration.languages[$_].disabled -ne $true})
    $content=Join-Path $source $(if($configuration.contentdir){$configuration.contentdir}else{'content'})
    if([IO.Path]::IsPathRooted([string]$configuration.contentdir)){$content=$configuration.contentdir}
    $pages=@(Get-GuideSourcePages -SourcePath $source -ConfigFiles $ConfigFiles -Target $Target -Configuration $configuration)
    function ArtifactRoute($url){
        $base=[uri]$configuration.baseurl
        Get-GuideArtifactRouteFromUri -Uri ([uri]$url) -BaseUri $base
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
                    $owners=@($pages|Where-Object {
                        $pageFile=[IO.Path]::GetFullPath((Join-Path $source $_.path))
                        [IO.Path]::GetDirectoryName($pageFile) -ieq $editionDirectory.FullName -and
                        [IO.Path]::GetFileName($pageFile) -iin @('index.md',"index.$language.md")
                    }|ForEach-Object {ArtifactRoute $_.permalink}|Sort-Object -Unique)
                    $download=@{path=$relative;handling='supplied';publicationRoots=$owners}

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
    # A whole-guide exclusion must be explicit in the source and confirmed by Hugo.
    # Do not interpret a missing artifact, draft, or a path-specific cascade as one.
    $excludedByRing=@{}
    foreach($guide in $guides){
        $metadata=(Read-GuideDocument (Join-Path $WorkspaceRoot "$($guide.contentRoot)/_index.md")).Metadata
        foreach($cascade in @($metadata['cascade'])){
            if($cascade -isnot [Collections.IDictionary]){continue}
            $build=$cascade['build'];$match=$cascade['target']
            if($build -isnot [Collections.IDictionary] -or $match -isnot [Collections.IDictionary]){continue}
            if($build['render'] -ne 'never' -or $build['list'] -ne 'never' -or @($match.Keys|Where-Object {$_ -ne 'environment'}).Count){continue}
            $ring=[string]$match['environment']
            if($ring -notin @('canary','preview','production')){continue}
            if(-not $excludedByRing.ContainsKey($ring)){$excludedByRing[$ring]=@()}
            $excludedByRing[$ring]+=$guide.id
        }
    }
    $pagesByRing=@{};$pagesByRing[$Target]=$pages
    $baseByRing=@{};$baseByRing[$Target]=$configuration['baseurl']
    $hasMin=$configuration.languages.Contains('min')
    $environments=@(foreach($ring in @('canary','preview','production')){
        $config=Join-Path $source "hugo.$ring.yaml"
        if(-not (Test-Path $config)){continue}
        $effective=(Get-GuideHugoConfiguration -SourcePath $source -ConfigFiles @('hugo.yaml',"hugo.$ring.yaml",$ConfigFiles[-1]) -Target $ring).Configuration
        if($effective.languages.Contains('min')){$hasMin=$true}
        $baseByRing[$ring]=$effective['baseurl']
        if($excludedByRing.Count -and -not $pagesByRing.ContainsKey($ring)){
            $pagesByRing[$ring]=@(Get-GuideSourcePages -SourcePath $source -ConfigFiles @('hugo.yaml',"hugo.$ring.yaml",$ConfigFiles[-1]) -Target $ring -Configuration $effective)
        }
        @{name=$ring;excludedLanguages=@($effective.languages.Keys|Where-Object {$effective.languages[$_].disabled -eq $true});excludedGuides=@()}
    })
    foreach($environment in $environments){foreach($id in @($excludedByRing[$environment.name])){
        if(-not $id){continue}
        $guide=$guides|Where-Object id -CEQ $id
        $directory=[IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $guide.contentRoot))+[IO.Path]::DirectorySeparatorChar
        $published=@($pagesByRing[$environment.name]|Where-Object {[IO.Path]::GetFullPath((Join-Path $source $_.path)).StartsWith($directory,[StringComparison]::OrdinalIgnoreCase)})
        if($published.Count){continue} # A descendant may override its parent's cascade.
        $knownPages=@(foreach($ring in $pagesByRing.Keys){foreach($page in $pagesByRing[$ring]){
            if([IO.Path]::GetFullPath((Join-Path $source $page.path)).StartsWith($directory,[StringComparison]::OrdinalIgnoreCase)){
                @{path=$page.path;route=(Get-GuideArtifactRouteFromUri -Uri ([uri]$page.permalink) -BaseUri ([uri]$baseByRing[$ring]))}
            }
        }})
        $prefixes=@($knownPages|ForEach-Object {
            # Each permalink retains Hugo's custom URLs and language directories.
            if($_.route){$_.route.Trim('/')}
            $document=Read-GuideDocument ([IO.Path]::GetFullPath((Join-Path $source $_.path)))
            $language=Language ([IO.Path]::GetFileName($_.path))
            $prefix=if($language -eq $default -and -not $configuration.defaultcontentlanguageinsubdir){''}else{"$($language.ToLowerInvariant())/"}
            foreach($alias in @($document.Metadata['aliases'])){
                if($alias -and ([string]$alias).StartsWith('/')){$prefix+([string]$alias).Trim('/')}
            }
        }|Where-Object {$_}|Sort-Object -Unique)
        if(-not $prefixes.Count){throw "Cannot discover public paths for excluded guide '$id'; provide a source environment where it is published."}
        $guide.artifactPrefixes=$prefixes
        $environment.excludedGuides+= $id
    }}
    $routes=@($pages|ForEach-Object {ArtifactRoute $_.permalink}|Sort-Object -Unique)
    $indexes=@(foreach($language in $languages){
        $prefix=if($language -eq $default -and -not $configuration.defaultcontentlanguageinsubdir){'/'}else{"/$language/"}
        $homeFormats=@($configuration.outputs.home)
        $homeFile=Join-Path $content $(if($language -eq $default){'_index.md'}else{"_index.$language.md"})
        if(Test-Path $homeFile){
            $homeDocument=Read-GuideDocument $homeFile
            if($homeDocument.Metadata.Contains('outputs')){$homeFormats=@($homeDocument.Metadata.outputs)}
        }
        foreach($format in $homeFormats){
            $definition=$configuration.outputformats[$format]
            if($definition.mediatype -notmatch 'json'){continue}
            $formatPath=([string]$definition['path']).Trim('/')
            $media=$configuration.mediatypes[$definition.mediatype]
            $suffix=@($media.suffixes)[0]
            $delimiter=if($media.Contains('delimiter')){[string]$media.delimiter}else{'.'}
            @{route=$prefix+$(if($formatPath){$formatPath+'/'})+$definition.basename+$delimiter+$suffix;requiredRoutes=@()}
        }
    })
    $indexes=@($indexes|Sort-Object route -Unique)
    # Alias pages are not members of Hugo .Pages; require their generated routes explicitly.
    foreach($guide in $guides){
        if(@($environments|Where-Object name -CEQ $Target|ForEach-Object excludedGuides) -ccontains $guide.id){continue}
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
    $inventory=@{schemaVersion=1;siteId=(Split-Path $WorkspaceRoot -Leaf);wrapper=@{discovery='source';jsonIndexes=$indexes;jsonFileNames=@(Get-GuideJsonFileNames -Configuration $configuration);sourcePath=$SourcePath;requiredRoutes=$routes;requiredFiles=@($requiredFiles);requiredI18nKeys=@();integrationPoints=@();legacyAliases=$aliases};guides=$guides;publication=@{environments=$environments;permanentExclusions=@(if($hasMin){@{environment='production';subject='language';id='min';reason='Minionese must never be published to production.'}})};protectedPaths=@()}
    return $inventory
}
