function Invoke-GuideTranslationProbe {
    param([string]$SourcePath,[string[]]$ConfigFiles,[string]$Target,[string]$ProbePath,[string]$OverlayPath,[string]$Pass)
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=(Get-Command hugo -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.Environment['GOWORK']='off';$start.Environment['GOFLAGS']='-mod=readonly'
    $start.Environment['HUGO_RESOURCEDIR']=Join-Path $ProbePath 'resources'
    $destination=Join-Path $ProbePath $Pass
    # Go's nested VCS paths exceed Windows limits below per-probe evidence folders.
    # Keep immutable module caches short; probe outputs/resources remain isolated.
    $cache=if($IsWindows){Join-Path ([IO.Path]::GetTempPath()) 'ogp-hugo-cache'}else{Join-Path $ProbePath 'cache'}
    $cursor=[IO.Path]::GetFullPath($cache)
    while($cursor){
        if((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Linked Hugo module cache is unsupported.'}
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
    $arguments=@('--source',$SourcePath,'--contentDir',(Join-Path $ProbePath 'content'),'--layoutDir',(Join-Path $ProbePath 'layouts'),'--config',(($ConfigFiles+@($OverlayPath))-join ','),'--environment',$Target,'--destination',$destination,'--cacheDir',$cache,'--noBuildLock','--printI18nWarnings')
    foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try {
        $null=$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        $timedOut=-not $process.WaitForExit(60000)
        if($timedOut){$process.Kill($true);$process.WaitForExit()}
        $log=$stdout.GetAwaiter().GetResult()+"`n"+$stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $ProbePath "$Pass.log"),$log)
        if($timedOut -or $process.ExitCode -ne 0 -or $log -match '(?m)^ERROR'){throw "Hugo translation probe failed; inspect $Pass.log."}
        foreach($file in Get-ChildItem -LiteralPath $destination -Recurse -File -Filter '*.html'){
            $text=[IO.File]::ReadAllText($file.FullName)
            if(-not $text.TrimStart().StartsWith('{')){continue}
            try{$record=ConvertFrom-Json -InputObject $text -ErrorAction Stop}catch{continue}
            if($record.PSObject.Properties['kind'] -and $record.kind -eq 'OpenGuidePlatformI18nProbe'){$record}
        }
    } finally {$process.Dispose()}
}
function Get-GuideEffectiveTranslations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string[]]$ConfigFiles,
        [Parameter(Mandatory)][string[]]$RequiredKeys,
        [Parameter(Mandatory)][string]$WorkspaceRoot,
        [Parameter(Mandatory)][string]$OutputPath,
        [ValidateSet('local','canary','preview','production')][string]$Target='local'
    )
    if($OutputPath -notmatch '^\.processing/[A-Za-z0-9/_-]+$'){throw 'Translation probe output must be a fresh directory under .processing.'}
    $probe=[IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $OutputPath))
    $cursor=$probe
    while($cursor){if(Test-Path -LiteralPath $cursor){if((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked translation probe output is not supported.'}};$cursor=[IO.Path]::GetDirectoryName($cursor)}
    if(Test-Path -LiteralPath $probe){throw 'Translation probe output already exists.'}
    if(@($RequiredKeys|Where-Object {[string]::IsNullOrWhiteSpace($_)}).Count){throw 'Translation keys must be nonempty.'}
    $keys=@($RequiredKeys|Select-Object -Unique)
    $configuration=(Get-GuideHugoConfiguration -SourcePath $SourcePath -ConfigFiles $ConfigFiles -Target $Target).Configuration
    $languages=@($configuration.languages.Keys|Where-Object {$configuration.languages[$_].disabled -ne $true}|Sort-Object)
    [IO.Directory]::CreateDirectory((Join-Path $probe 'content'))|Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $probe 'layouts'))|Out-Null
    [IO.File]::WriteAllText((Join-Path $probe 'content/_index.md'),"---`ntitle: Translation probe`n---`n")
    [IO.File]::WriteAllText((Join-Path $probe 'layouts/home.html'),[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'probe.html')))
    $passes=@{}
    foreach($pass in @('resolved','placeholders')){
        $overlay=@{
            disableKinds=@('page','section','taxonomy','term','RSS','sitemap','robotsTXT','404')
            outputs=@{home=@('HTML')};enableMissingTranslationPlaceholders=($pass -eq 'placeholders')
            minify=@{minifyOutput=$false};params=@{openGuidePlatformProbeKeys=$keys}
        }
        $overlayPath=Join-Path $probe "$pass.json"
        [IO.File]::WriteAllText($overlayPath,($overlay|ConvertTo-Json -Depth 20))
        $passes[$pass]=@(Invoke-GuideTranslationProbe -SourcePath ([IO.Path]::GetFullPath($SourcePath)) -ConfigFiles $ConfigFiles -Target $Target -ProbePath $probe -OverlayPath $overlayPath -Pass $pass)
    }
    $records=@(foreach($language in $languages){
        $resolved=@($passes.resolved|Where-Object language -CEQ $language)
        $placeholders=@($passes.placeholders|Where-Object language -CEQ $language)
        if($resolved.Count -ne 1 -or $placeholders.Count -ne 1){throw "Translation probe lacks unique evidence for $language."}
        $entries=@(foreach($key in $keys){
            $value=@($resolved[0].keys|Where-Object key -CEQ $key)
            $placeholder=@($placeholders[0].keys|Where-Object key -CEQ $key)
            if($value.Count -ne 1 -or $placeholder.Count -ne 1){throw "Translation probe lacks unique evidence for $language/$key."}
            $state=if([string]::IsNullOrWhiteSpace($value[0].value)){'missing'}elseif($placeholder[0].value -ceq "[i18n] $key"){'fallback'}else{'available'}
            [pscustomobject]@{Key=$key;State=$state;Value=$value[0].value;Origin=if($state -eq 'fallback'){'hugo-reported-fallback'}else{'not-established'}}
        })
        [pscustomobject]@{Language=$language;Keys=$entries;Scope='hugo-effective-i18n';TranslationQualityAssessed=$false}
    })
    $result=[pscustomobject]@{Target=$Target;Languages=$records;Scope='Hugo resolution for required keys without interpolation context; not plural-form completeness or translation quality.'}
    [IO.File]::WriteAllText((Join-Path $probe 'translations.json'),($result|ConvertTo-Json -Depth 30))
    $result
}