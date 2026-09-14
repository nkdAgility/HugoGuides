function Get-GuideSourceTranslations {
    param([string]$SourcePath,[string[]]$ConfigFiles,[string]$Target,[string[]]$RequiredKeys)
    $configuration=(Get-GuideHugoConfiguration -SourcePath $SourcePath -ConfigFiles $ConfigFiles -Target $Target).Configuration
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=(Get-Command hugo -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.Environment['GOWORK']='off';$start.Environment['GOFLAGS']='-mod=readonly'
    foreach($argument in @('config','mounts','--source',$SourcePath,'--config',($ConfigFiles -join ','),'--environment',$Target)){$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try{
        $null=$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)){$process.Kill($true);throw 'Hugo catalogue mount listing timed out.'}
        $raw=$stdout.GetAwaiter().GetResult();$diagnostics=$stderr.GetAwaiter().GetResult()
        if($process.ExitCode -ne 0){throw "Hugo catalogue mount listing failed: $diagnostics"}
        $first=$raw.IndexOf('{');if($first -lt 0){throw 'Hugo did not return catalogue mounts.'}
        $modules=('['+($raw.Substring($first) -replace '(?m)^}\s*\r?\n{','},{')+']')|ConvertFrom-Json -AsHashtable
    }finally{$process.Dispose()}
    Import-Module powershell-yaml -MinimumVersion 0.4.12
    $catalogues=@{}
    foreach($module in $modules){foreach($mount in $module.mounts){
        if($mount.target -ne 'i18n' -and -not $mount.target.StartsWith('i18n/')){continue}
        foreach($filter in @('includeFiles','excludeFiles')){if($mount.Contains($filter) -and $mount[$filter]){throw "Source catalogue inspection cannot yet establish filtered mount $($mount.source). No runtime evidence was assumed."}}
        $directory=Join-Path $module.dir $mount.source
        if(-not (Test-Path -LiteralPath $directory)){continue}
        $mounted=Get-Item -LiteralPath $directory
        $files=if($mounted.PSIsContainer){@(Get-ChildItem -LiteralPath $directory -File)}else{@($mounted)}
        foreach($file in $files){
            if($file.Extension -eq '.toml'){throw "Source catalogue inspection cannot yet read TOML catalogue $($file.FullName). No runtime evidence was assumed."}
            if($file.Extension -notin @('.yaml','.yml','.json')){continue}
            $language=if($mounted.PSIsContainer){$file.BaseName}else{[IO.Path]::GetFileNameWithoutExtension($mount.target)}
            if(-not $catalogues.ContainsKey($language)){$catalogues[$language]=@{}}
            $text=[IO.File]::ReadAllText($file.FullName)
            $data=if($file.Extension -eq '.json'){$text|ConvertFrom-Json -AsHashtable}else{ConvertFrom-Yaml $text}
            $entries=if($data -is [Collections.IDictionary]){@($data.Keys|ForEach-Object {@{id=$_;value=$data[$_]}})}else{@($data|ForEach-Object {@{id=$_.id;value=$_}})}
            foreach($entry in $entries){
                if($catalogues[$language].ContainsKey($entry.id)){continue}
                $value=$entry.value
                $values=if($value -is [Collections.IDictionary]){@($value.Keys|Where-Object {$_ -in @('translation','zero','one','two','few','many','other')}|ForEach-Object {$value[$_]})}else{@($value)}
                $catalogues[$language][$entry.id]=[string](@($values|Where-Object {$_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_)}) -join ' ')
            }
        }
    }}
    foreach($language in $configuration.languages.Keys|Where-Object {$configuration.languages[$_].disabled -ne $true}){
        $keys=@(foreach($key in $RequiredKeys){
            $value=$null;$state='missing'
            foreach($candidate in @($language,[string]$configuration.defaultcontentlanguage)|Select-Object -Unique){
                if($catalogues.ContainsKey($candidate) -and $catalogues[$candidate].ContainsKey($key) -and $catalogues[$candidate][$key]){
                    $value=$catalogues[$candidate][$key];$state=if($candidate -eq $language){'available'}else{'fallback'};break
                }
            }
            [pscustomobject]@{Key=$key;Value=$value;State=$state}
        })
        [pscustomobject]@{Language=$language;Keys=$keys;Scope='source-i18n';TranslationQualityAssessed=$false}
    }
}
