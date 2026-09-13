function Get-GuideArtifactRouteCandidates {
    param([Parameter(Mandatory)][string]$Route)
    if(-not $Route.StartsWith('/') -or $Route.StartsWith('//') -or $Route -match '[\\?#\x00-\x20]'){
        throw "Unsafe root-relative artifact route: $Route"
    }
    if($Route -eq '/'){return 'index.html'}
    $relative=$Route.Substring(1)
    $directoryRoute=$relative.EndsWith('/')
    if($directoryRoute){$relative=$relative.Substring(0,$relative.Length-1)}
    $segments=foreach($segment in $relative.Split('/')){
        if(-not $segment -or $segment -match '%(?![0-9A-Fa-f]{2})'){throw "Unsafe artifact route segment: $Route"}
        $decoded=[Uri]::UnescapeDataString($segment)
        # Decode exactly once. Encoded path separators and traversal are never
        # interpreted as filesystem navigation; preserve Unicode without normalization.
        if($decoded -in @('.','..') -or $decoded -match '[/\\:?#\x00-\x1f\x7f]'){
            throw "Unsafe artifact route segment: $Route"
        }
        $decoded
    }
    $path=$segments -join '/'
    if($directoryRoute){return "$path/index.html"}
    # Hugo can render dotted edition/slug paths as directories. Consult the
    # actual artifact rather than treating a dot as proof of a file extension.
    $path
    "$path/index.html"
}
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
    param([Parameter(Mandatory)][string]$ArtifactRoot,[string[]]$RequiredRoutes=@('/'),[string[]]$RequiredDownloads=@(),[string[]]$ForbiddenPaths=@(),[long]$MaximumBytes=524288000,[string[]]$HugoLog=@(),[hashtable]$AllowedLegacyDuplicates=@{})
    $files=@(Get-GuideArtifactFiles $ArtifactRoot)
    $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($file in $files){$null=$paths.Add($file.Path)}
    $findings=[Collections.Generic.List[object]]::new()
    function Add-ArtifactFinding($code,$path,$message){$findings.Add([pscustomobject]@{Code=$code;Path=$path;Message=$message})}
    function Assert-RelativeArtifactPath($path){
        if([string]::IsNullOrWhiteSpace($path) -or [IO.Path]::IsPathRooted($path) -or $path -match '[\\:?#%]' -or @($path.Split('/')|Where-Object {$_ -in @('..','.','')}).Count){throw "Unsafe artifact expectation: $path"}
    }
    foreach($route in $RequiredRoutes){
        $candidates=@(Get-GuideArtifactRouteCandidates $route)
        if(-not @($candidates|Where-Object {$paths.Contains($_)}).Count){
            Add-ArtifactFinding REQUIRED_ROUTE_MISSING $candidates[0] "Required route is absent: $route"
        }
    }
    foreach($path in $RequiredDownloads){Assert-RelativeArtifactPath $path;if(-not $paths.Contains($path)){Add-ArtifactFinding REQUIRED_DOWNLOAD_MISSING $path 'Restore the declared download in the build artifact.'}}
    foreach($path in $ForbiddenPaths){
        $prefix=$path.TrimEnd('/');Assert-RelativeArtifactPath $prefix
        foreach($file in $files){if($file.Path -ceq $prefix -or $file.Path.StartsWith($prefix+'/',[StringComparison]::Ordinal)){Add-ArtifactFinding FORBIDDEN_RESOURCE_PRESENT $file.Path 'Remove this prohibited resource from the artifact through reviewed publication configuration.'}}
    }
    foreach($line in $HugoLog){
        if($line -match '^WARN\s+Duplicate target paths:\s*(?<targets>.+)$'){
            $reported=$Matches.targets
            $entries=@([regex]::Matches($reported,'(?:^|,\s*)(?<path>[^,]+?)\s+\((?<count>\d+)\)'))
            $reconstructed=($entries|ForEach-Object {$_.Value.TrimStart(',',' ')}) -join ', '
            $approved=$entries.Count -gt 0 -and $reconstructed -ceq $reported
            foreach($entry in $entries){
                $target=$entry.Groups['path'].Value;$count=[int]$entry.Groups['count'].Value
                if($target -cnotmatch '^(?:[A-Za-z0-9-]+/)?(?:download|downloads|translationsdirectory)/index\.html$' -or -not $AllowedLegacyDuplicates.ContainsKey($target) -or $AllowedLegacyDuplicates[$target] -ne $count){$approved=$false}
            }
            if($approved){continue}
            Add-ArtifactFinding HUGO_DUPLICATE_TARGETS 'Hugo output paths' "Assign one owner to each output path; remove conflicting aliases or routes. Hugo reported: $reported"
        }
    }
    $size=0L
    foreach($file in $files){
        $size+=$file.Length
        if([IO.Path]::GetExtension($file.Path) -eq '.html' -and [IO.File]::ReadAllText($file.FullName) -match '\[i18n\]\s+[A-Za-z0-9_]+'){
            Add-ArtifactFinding MISSING_RENDERED_TRANSLATION $file.Path 'Supply the missing catalogue key shown by the rendered i18n placeholder.'
        }
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