function Get-GuidePreparedInputs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$WorkspaceRoot,
        [Parameter(Mandatory)][Collections.IDictionary]$Policy,
        [Parameter(Mandatory)][string]$PolicyPath,
        [Parameter(Mandatory)][string]$PlatformRoot,
        [Parameter(Mandatory)][string]$OverlayPath,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Target
    )
    $records=[Collections.Generic.SortedDictionary[string,string]]::new([StringComparer]::Ordinal)
    function Add-InputFile([string]$Path,[string]$Key){
        if(-not [IO.File]::Exists($Path)){$records[$Key]='missing';return}
        if((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Linked prepared input is unsupported: $Key"}
        $records[$Key]=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    function Add-InputTree([string]$Directory,[string]$Prefix){
        if(-not [IO.Directory]::Exists($Directory)){$records[$Prefix]='missing';return}
        $pending=[Collections.Generic.Stack[string]]::new();$pending.Push($Directory)
        while($pending.Count){
            $current=$pending.Pop()
            foreach($item in Get-ChildItem -LiteralPath $current -Force){
                $relative=[IO.Path]::GetRelativePath($Directory,$item.FullName).Replace('\','/')
                # Exclude only repository metadata and platform output, never arbitrary wrapper resource/content directories.
                if($relative -match '^(?:\.git|\.processing)(?:/|$)' -or $item.Name -eq '.hugo_build.lock'){continue}
                if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Linked prepared input is unsupported: $Prefix/$relative"}
                if($item.PSIsContainer){$pending.Push($item.FullName)}else{Add-InputFile $item.FullName "$Prefix/$relative"}
            }
        }
    }
    Add-InputTree (Resolve-GuideWorkspacePath $WorkspaceRoot $Policy.wrapper.sourcePath) 'site'
    foreach($guide in $Policy.guides){Add-InputTree (Resolve-GuideWorkspacePath $WorkspaceRoot $guide.contentRoot) "guide/$($guide.id)"}
    foreach($path in $Policy.wrapper.requiredFiles){Add-InputFile (Resolve-GuideWorkspacePath $WorkspaceRoot $path) "wrapper/$path"}
    Add-InputFile (Resolve-GuideWorkspacePath $WorkspaceRoot $PolicyPath) 'policy'
    foreach($path in @('go.mod','go.sum','go.work','go.work.sum','staticwebapp.config.json','staticwebapp.config.canary.json','staticwebapp.config.preview.json','staticwebapp.config.production.json')){
        Add-InputFile (Join-Path $WorkspaceRoot $path) "workspace/$path"
    }
    foreach($component in @('OpenGuidePlatform.PowerShell.Core','OpenGuidePlatform.PowerShell.Build','OpenGuidePlatform.Hugo.Guides')){
        Add-InputTree (Join-Path $PlatformRoot "system/$component") "platform/$component"
    }
    # Runtime scripts are the same in the source checkout and distributed package.
    foreach($file in @('build.ps1','.build/Build-GuideSite.ps1','.build/Prepare-GuideSite.ps1','.build/Test-GuideSiteNavigation.ps1','.build/Write-GuideSiteValidationSummary.ps1')){
        Add-InputFile (Join-Path $PlatformRoot $file) "platform/$file"
    }
    Add-InputFile $OverlayPath 'configuration-overlay'
    foreach($entry in Get-ChildItem Env: | Where-Object { $_.Name -match '^HUGO_' -and $_.Name -notin @('HUGO_RESOURCEDIR','HUGO_CACHEDIR') } | Sort-Object Name){
        # Store only hashes; environment values may contain deployment data.
        $records["environment/$($entry.Name)"]=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($entry.Value))).ToLowerInvariant()
    }
    foreach($name in @('GOFLAGS','GOWORK')){
        $value=[Environment]::GetEnvironmentVariable($name)
        $records["environment/$name"]=if($null -eq $value){'unset'}else{[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($value))).ToLowerInvariant()}
    }
    $inputText="version=$Version`ntarget=$Target`n"+(@($records.GetEnumerator()|ForEach-Object {"$($_.Key)=$($_.Value)"}) -join "`n")
    [pscustomobject]@{SchemaVersion=1;Version=$Version;Target=$Target;Files=$records;Sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($inputText))).ToLowerInvariant()}
}
function Assert-GuidePreparedInputs {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Expected,[Parameter(Mandatory)]$Actual)
    if($Expected.SchemaVersion -ne 1 -or $Expected.Sha256 -cne $Actual.Sha256){throw 'PREPARE_INPUTS_CHANGED: Assessed source, configuration, platform code or selected version changed. Run Prepare again into a fresh output directory.'}
}
function Get-GuidePreparedBuildTools {
    [CmdletBinding()]
    param()
    $tools=[ordered]@{PowerShell=$PSVersionTable.PSVersion.ToString()}
    foreach($name in @('hugo','go')){
        $command=Get-Command $name -CommandType Application -ErrorAction Stop|Select-Object -First 1
        $tools[$name]=(Get-FileHash -LiteralPath $command.Source).Hash.ToLowerInvariant()
    }
    Import-Module powershell-yaml -RequiredVersion 0.4.12 -ErrorAction Stop
    $yaml=Get-Module powershell-yaml|Select-Object -First 1
    $tools['powershell-yaml']=(Get-FileHash -LiteralPath $yaml.Path).Hash.ToLowerInvariant()
    $json=$tools|ConvertTo-Json -Compress
    [pscustomobject]@{Tools=$tools;Sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()}
}