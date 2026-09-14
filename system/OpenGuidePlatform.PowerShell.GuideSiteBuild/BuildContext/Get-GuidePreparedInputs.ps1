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
    $pathComparer=if($IsWindows){[StringComparer]::OrdinalIgnoreCase}else{[StringComparer]::Ordinal}
    $visitedFiles=[Collections.Generic.HashSet[string]]::new($pathComparer)
    $visitedDirectories=[Collections.Generic.HashSet[string]]::new($pathComparer)
    function Get-InputKey([string]$Path){
        $relative=[IO.Path]::GetRelativePath($WorkspaceRoot,$Path).Replace('\','/')
        if($relative -ne '..' -and -not $relative.StartsWith('../')){return "workspace/$relative"}
        $relative=[IO.Path]::GetRelativePath($PlatformRoot,$Path).Replace('\','/')
        return "platform/$relative"
    }
    function Add-InputFile([string]$Path){
        $Path=[IO.Path]::GetFullPath($Path)
        if(-not $visitedFiles.Add($Path)){return}
        $Key=Get-InputKey $Path
        if(-not [IO.File]::Exists($Path)){$records[$Key]='missing';return}
        if((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Linked prepared input is unsupported: $Key"}
        $records[$Key]=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    function Add-InputTree([string]$Directory,[string]$Prefix){
        if(-not [IO.Directory]::Exists($Directory)){$records[(Get-InputKey $Directory)]='missing';return}
        $pending=[Collections.Generic.Stack[string]]::new();$pending.Push($Directory)
        while($pending.Count){
            $current=$pending.Pop()
            if(-not $visitedDirectories.Add([IO.Path]::GetFullPath($current))){continue}
            foreach($item in Get-ChildItem -LiteralPath $current -Force){
                $relative=[IO.Path]::GetRelativePath($Directory,$item.FullName).Replace('\','/')
                # Exclude only repository metadata and platform output, never arbitrary wrapper resource/content directories.
                if($relative -match '^(?:\.git|\.processing)(?:/|$)' -or $item.Name -eq '.hugo_build.lock'){continue}
                if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Linked prepared input is unsupported: $Prefix/$relative"}
                if($item.PSIsContainer){$pending.Push($item.FullName)}else{Add-InputFile $item.FullName}
            }
        }
    }
    Add-InputTree (Resolve-GuideWorkspacePath $WorkspaceRoot $Policy.wrapper.sourcePath) 'site'
    foreach($guide in $Policy.guides){Add-InputTree (Resolve-GuideWorkspacePath $WorkspaceRoot $guide.contentRoot) "guide/$($guide.id)"}
    foreach($path in $Policy.wrapper.requiredFiles){Add-InputFile (Resolve-GuideWorkspacePath $WorkspaceRoot $path)}
    Add-InputFile (Resolve-GuideWorkspacePath $WorkspaceRoot $PolicyPath)
    foreach($path in @('guide-site.delivery.yaml','.github/GitVersion.yml','go.mod','go.sum','go.work','go.work.sum','staticwebapp.config.json','staticwebapp.config.canary.json','staticwebapp.config.preview.json','staticwebapp.config.production.json')){
        Add-InputFile (Join-Path $WorkspaceRoot $path)
    }
    foreach($component in @('OpenGuidePlatform.PowerShell.Core','OpenGuidePlatform.PowerShell.GuideSiteBuild','OpenGuidePlatform.Hugo.Guides')){
        Add-InputTree (Join-Path $PlatformRoot "system/$component") "platform/$component"
    }
    foreach($guide in $Policy.guides){foreach($edition in $guide.editions){foreach($translation in $edition.translations){foreach($download in $translation.downloads){
        if($download.Contains('generationReceipt')){Add-InputFile (Resolve-GuideWorkspacePath $WorkspaceRoot $download.generationReceipt.path)}
    }}}}
    foreach($file in @('platform.json','platform-resolution.json','build.ps1')){
        Add-InputFile (Join-Path $PlatformRoot $file)
    }
    Add-InputFile $OverlayPath
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
    $json=$tools|ConvertTo-Json -Compress
    [pscustomobject]@{Tools=$tools;Sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()}
}