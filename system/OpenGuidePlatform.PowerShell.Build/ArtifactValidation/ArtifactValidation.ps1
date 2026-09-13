function Get-GuideArtifactFiles {
    param([Parameter(Mandatory)][string]$ArtifactRoot)
    $root=[IO.Path]::GetFullPath($ArtifactRoot)
    if(-not [IO.Directory]::Exists($root)){throw 'Artifact directory is missing.'}
    $cursor=$root
    while($cursor){if((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked artifact paths are not supported.'};$cursor=[IO.Path]::GetDirectoryName($cursor)}
    $directories=[Collections.Generic.Queue[string]]::new();$directories.Enqueue($root)
    while($directories.Count){foreach($entry in Get-ChildItem -LiteralPath $directories.Dequeue() -Force){
        if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Linked artifact entry: $($entry.Name)"}
        if($entry.PSIsContainer){$directories.Enqueue($entry.FullName)}else{
            [pscustomobject]@{Path=[IO.Path]::GetRelativePath($root,$entry.FullName).Replace('\','/');FullName=$entry.FullName;Length=$entry.Length;Sha256=(Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
        }
    }}
}
function Test-GuideArtifact {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ArtifactRoot,[string[]]$RequiredRoutes=@('/'),[string[]]$RequiredDownloads=@(),[string[]]$ForbiddenPaths=@(),[long]$MaximumBytes=524288000)
    $files=@(Get-GuideArtifactFiles $ArtifactRoot)
    $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($file in $files){$null=$paths.Add($file.Path)}
    $findings=[Collections.Generic.List[object]]::new()
    function Add-ArtifactFinding($code,$path,$message){$findings.Add([pscustomobject]@{Code=$code;Path=$path;Message=$message})}
    function Assert-RelativeArtifactPath($path){
        if([string]::IsNullOrWhiteSpace($path) -or [IO.Path]::IsPathRooted($path) -or $path -match '[\\:?#%]' -or @($path.Split('/')|Where-Object {$_ -in @('..','.','')}).Count){throw "Unsafe artifact expectation: $path"}
    }
    foreach($route in $RequiredRoutes){
        if(-not $route.StartsWith('/')){throw "Expected a root-relative route: $route"}
        $relative=$route.TrimStart('/')
        if(-not $relative){$relative='index.html'}elseif($relative.EndsWith('/')){$relative+='index.html'}elseif(-not [IO.Path]::GetExtension($relative)){$relative+='/index.html'}
        Assert-RelativeArtifactPath $relative
        if(-not $paths.Contains($relative)){Add-ArtifactFinding REQUIRED_ROUTE_MISSING $relative "Required route is absent: $route"}
    }
    foreach($path in $RequiredDownloads){Assert-RelativeArtifactPath $path;if(-not $paths.Contains($path)){Add-ArtifactFinding REQUIRED_DOWNLOAD_MISSING $path 'Restore the declared download in the build artifact.'}}
    foreach($path in $ForbiddenPaths){
        $prefix=$path.TrimEnd('/');Assert-RelativeArtifactPath $prefix
        foreach($file in $files){if($file.Path -ceq $prefix -or $file.Path.StartsWith($prefix+'/',[StringComparison]::Ordinal)){Add-ArtifactFinding FORBIDDEN_RESOURCE_PRESENT $file.Path 'Remove this prohibited resource from the artifact through reviewed publication configuration.'}}
    }
    $size=0L
    foreach($file in $files){
        $size+=$file.Length
        if([IO.Path]::GetExtension($file.Path) -eq '.json'){try{$null=ConvertFrom-Json ([IO.File]::ReadAllText($file.FullName)) -ErrorAction Stop}catch{Add-ArtifactFinding INVALID_JSON $file.Path 'Correct the generated JSON.'}}
        if([IO.Path]::GetExtension($file.Path) -in @('.html','.json','.xml','.yaml','.yml')){if([IO.File]::ReadAllText($file.FullName) -match '#\{[A-Za-z0-9_.]+\}#'){Add-ArtifactFinding UNRESOLVED_TOKEN $file.Path 'Supply the missing build value through the configuration overlay.'}}
    }
    if($size -gt $MaximumBytes){Add-ArtifactFinding ARTIFACT_TOO_LARGE '.' "Artifact size $size exceeds limit $MaximumBytes."}
    [pscustomobject]@{Outcome=if($findings.Count){'fail'}else{'pass'};Files=$files;SizeBytes=$size;Findings=$findings.ToArray()}
}
function New-GuideArtifactIdentity {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ArtifactRoot,[Parameter(Mandatory)][string]$Target,[Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$SourceCommit,[Parameter(Mandatory)][string]$Version,[bool]$SourceDirty=$false)
    [ordered]@{schemaVersion=1;target=$Target;sourceCommit=$SourceCommit;sourceDirty=$SourceDirty;version=$Version;files=@(Get-GuideArtifactFiles $ArtifactRoot|Sort-Object Path|ForEach-Object {[ordered]@{path=$_.Path;sha256=$_.Sha256;length=$_.Length}})}
}
function Test-GuideArtifactIdentity {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ArtifactRoot,[Parameter(Mandatory)]$Identity,[Parameter(Mandatory)][string]$ExpectedTarget,[Parameter(Mandatory)][string]$ExpectedSourceCommit)
    if($Identity.schemaVersion -ne 1 -or $Identity.target -cne $ExpectedTarget -or $Identity.sourceCommit -cne $ExpectedSourceCommit){throw 'Artifact identity does not match the expected source commit and target.'}
    $actual=@(Get-GuideArtifactFiles $ArtifactRoot)
    if($actual.Count -ne $Identity.files.Count){throw 'Artifact file inventory changed after Build.'}
    $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($record in $Identity.files){
        if(-not $seen.Add($record.path)){throw 'Artifact identity contains duplicate file paths.'}
        $match=@($actual|Where-Object Path -CEQ $record.path)
        if($match.Count -ne 1 -or $match[0].Sha256 -cne $record.sha256 -or $match[0].Length -ne $record.length){throw "Artifact changed after Build: $($record.path)"}
    }
    $true
}