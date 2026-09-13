function Get-GuidePdfPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][System.Collections.IDictionary]$Policy,[Parameter(Mandatory)][string]$GuideId,[Parameter(Mandatory)][string]$EditionId,[Parameter(Mandatory)][string]$Language,[Parameter(Mandatory)][string]$DownloadPath,[hashtable]$FontOverrides=@{},[string[]]$HeaderPaths=@(),[string[]]$LuaFilterPaths=@())
    $selection=Get-GuideSelection $Policy $GuideId $EditionId
    $translations=@($selection.Edition.translations|Where-Object { $_.language -eq $Language })
    if ($translations.Count -ne 1) { throw 'Select one declared translation.' }
    $downloads=@($translations[0].downloads|Where-Object { $_.path -ceq $DownloadPath })
    if ($downloads.Count -ne 1 -or $downloads[0].handling -ne 'generated') { throw 'Only an explicitly generated download may be generated; supplied and protected PDFs are preserved.' }
    $relative="$($selection.RelativePath)/$DownloadPath"
    Assert-GuideWriteAllowed $Policy $relative
    $output=Resolve-GuideWorkspacePath $WorkspaceRoot $relative
    if ([IO.Path]::GetExtension($output) -ne '.pdf') { throw 'PDF output must use the .pdf extension.' }
    $filename=if($Language -eq $selection.Edition.sourceLanguage){'index.md'}else{"index.$Language.md"}
    $inputPath=Resolve-GuideWorkspacePath $WorkspaceRoot "$($selection.RelativePath)/$filename"
    $document=Read-GuideDocument $inputPath
    if ([string]::IsNullOrWhiteSpace($document.Body)) { throw 'An empty translation has no PDF body to generate.' }
    $resolvedLanguage=Get-GuideLanguage $filename $selection.Edition.sourceLanguage
    $arguments=@($inputPath,'--pdf-engine=xelatex','--pdf-engine-opt=-interaction=nonstopmode','--metadata',"lang=$resolvedLanguage",'--metadata','keywords=')
    $resources=@()
    foreach ($path in $HeaderPaths) { $resolved=Resolve-GuideWorkspacePath $WorkspaceRoot $path;if(-not [IO.File]::Exists($resolved)){throw "Header missing: $path"};$resources+=$resolved;$arguments+=@('--include-in-header',$resolved) }
    foreach ($path in $LuaFilterPaths) { $resolved=Resolve-GuideWorkspacePath $WorkspaceRoot $path;if(-not [IO.File]::Exists($resolved)){throw "Filter missing: $path"};$resources+=$resolved;$arguments+=@('--lua-filter',$resolved) }
    $fonts=@{}
    foreach($key in @('mainfont','sansfont','monofont')) { if($document.Metadata.Contains($key)){$fonts[$key]=$document.Metadata[$key]} }
    foreach($key in $FontOverrides.Keys) { if($key -notin @('mainfont','sansfont','monofont')){throw "Unsupported font key: $key"};$fonts[$key]=$FontOverrides[$key];$arguments+=@('-V',"$key=$($FontOverrides[$key])") }
    $fingerprints=@(foreach($path in @($inputPath)+$resources){[pscustomobject]@{Path=[IO.Path]::GetRelativePath([IO.Path]::GetFullPath($WorkspaceRoot),$path).Replace('\','/');Sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}})
    [pscustomobject]@{WorkspaceRoot=[IO.Path]::GetFullPath($WorkspaceRoot);Guide=$GuideId;Edition=$EditionId;Language=$resolvedLanguage;Input=$inputPath;Output=$output;RelativeOutput=$relative;Arguments=$arguments;Fonts=$fonts;Fingerprints=$fingerprints;ConfigurationSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($Policy | ConvertTo-Json -Depth 40 -Compress)))).ToLowerInvariant()}
}
function Get-GuidePdfToolchain {
    [CmdletBinding()]
    param()
    foreach($name in @('pandoc','xelatex','fc-list')) {
        $command=Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if($null -eq $command) { [pscustomobject]@{Tool=$name;Available=$false;Version=$null};continue }
        $version=@(& $command.Source --version 2>&1)
        [pscustomobject]@{Tool=$name;Available=($LASTEXITCODE -eq 0);ExecutableSha256=(Get-FileHash -LiteralPath $command.Source -Algorithm SHA256).Hash.ToLowerInvariant();Version=if($version.Count){[string]$version[0]}else{$null}}
    }
}
function New-GuidePdf {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][System.Collections.IDictionary]$Policy,[Parameter(Mandatory)][string]$GuideId,[Parameter(Mandatory)][string]$EditionId,[Parameter(Mandatory)][string]$Language,[Parameter(Mandatory)][string]$DownloadPath,[hashtable]$FontOverrides=@{},[string[]]$HeaderPaths=@(),[string[]]$LuaFilterPaths=@(),[ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedOutputSha256,[ValidatePattern('^[a-fA-F0-9]{64}$')][string]$EnvironmentSha256)
    $plan=Get-GuidePdfPlan -WorkspaceRoot $WorkspaceRoot -Policy $Policy -GuideId $GuideId -EditionId $EditionId -Language $Language -DownloadPath $DownloadPath -FontOverrides $FontOverrides -HeaderPaths $HeaderPaths -LuaFilterPaths $LuaFilterPaths
    $replacing=[IO.File]::Exists($plan.Output)
    if ($replacing -and -not $ExpectedOutputSha256) { throw 'PDF already exists; supply its reviewed ExpectedOutputSha256 to replace it.' }
    if ($ExpectedOutputSha256 -and (-not $replacing -or (Get-FileHash -LiteralPath $plan.Output).Hash -ne $ExpectedOutputSha256)) { throw 'PDF changed since review or is missing.' }
    $toolchain=@(Get-GuidePdfToolchain)
    if (@($toolchain | Where-Object { $_.Tool -in @('pandoc','xelatex') -and -not $_.Available }).Count) { throw 'PDF generation requires Pandoc and XeLaTeX. Other Core commands do not.' }
    $fontCommand=Get-Command fc-list -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if($plan.Fonts.Count -and $null -eq $fontCommand){throw 'Font diagnostics require fc-list for explicitly selected fonts.'}
    if($fontCommand) {
        $families=@(& $fontCommand.Source --format '%{family}\n')
        if($LASTEXITCODE -ne 0){throw 'Font enumeration failed.'}
        $available=@($families | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() })
        foreach($font in $plan.Fonts.Values){if($font -notin $available){throw "Font is not installed: $font. Supply an explicit installed override; no fonts are installed or substituted automatically."}}
    }
    if ($PSCmdlet.ShouldProcess($plan.Output,'Generate a guide PDF with explicit language metadata')) {
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($plan.Output))|Out-Null
        $lockPath=$plan.Output+'.pdf-lock'
        $lock=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $tempDirectory=$plan.Output+'.staging-'+[guid]::NewGuid().ToString('N')
        $temporary=Join-Path $tempDirectory 'guide.pdf'
        try {
            [IO.Directory]::CreateDirectory($tempDirectory)|Out-Null
            $arguments=@($plan.Arguments)+@('-o',$temporary)
            $nativeExit=Invoke-GuidePandoc -Arguments $arguments
            if($nativeExit -ne 0){throw "Pandoc failed with exit code $nativeExit."}
            if(-not [IO.File]::Exists($temporary)){throw 'Pandoc did not create a PDF.'}
            $stream=[IO.File]::OpenRead($temporary)
            try{$magic=[byte[]]::new(5);$count=$stream.Read($magic,0,5)}finally{$stream.Dispose()}
            if($count -ne 5 -or [Text.Encoding]::ASCII.GetString($magic) -ne '%PDF-'){throw 'Generated output is not a PDF.'}
            $checked=Resolve-GuideWorkspacePath $WorkspaceRoot $plan.RelativeOutput
            Assert-GuideWriteAllowed $Policy $plan.RelativeOutput
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($checked))|Out-Null
            foreach ($fingerprint in $plan.Fingerprints) {
                $inputFile=Resolve-GuideWorkspacePath $WorkspaceRoot $fingerprint.Path
                if ((Get-FileHash -LiteralPath $inputFile).Hash -ne $fingerprint.Sha256) { throw 'PDF input changed during generation; output not published.' }
            }
            if ($replacing) {
                if (-not [IO.File]::Exists($checked) -or (Get-FileHash -LiteralPath $checked).Hash -ne $ExpectedOutputSha256) { throw 'PDF changed during generation; output not published.' }
                [IO.File]::Replace($temporary,$checked,[System.Management.Automation.Language.NullString]::Value)
            } else { [IO.File]::Move($temporary,$checked) }
            [pscustomobject]@{Status=if($replacing){'replaced'}else{'created'};Path=$plan.RelativeOutput;Language=$plan.Language;Sha256=(Get-FileHash $checked -Algorithm SHA256).Hash.ToLowerInvariant();Inputs=$plan.Fingerprints;ConfigurationSha256=$plan.ConfigurationSha256;Fonts=$plan.Fonts;Toolchain=$toolchain;VisualReviewRequired=$true;CacheKey=if($EnvironmentSha256){Get-GuidePdfCacheKey $plan $toolchain $EnvironmentSha256}else{$null}}
        } finally {
            try {
                # Delete only this operation's validated sibling staging directory.
                $stageRelative=[IO.Path]::GetRelativePath([IO.Path]::GetFullPath($WorkspaceRoot),$tempDirectory).Replace('\','/')
                $stage=Resolve-GuideWorkspacePath $WorkspaceRoot $stageRelative
                if ([IO.Directory]::Exists($stage)) { [IO.Directory]::Delete($stage,$true) }
            } finally { $lock.Dispose();[IO.File]::Delete($lockPath) }
        }
    }
}

function Invoke-GuidePandoc {
    param([string[]]$Arguments)
    & pandoc @Arguments | Out-Host
    return $LASTEXITCODE
}
