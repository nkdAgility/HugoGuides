function Resolve-GuideWorkspacePath {
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$RelativePath)
    if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '[\\:]' -or ($RelativePath.Split('/') | Where-Object { $_ -in @('..','.git') })) { throw "Unsafe workspace path: $RelativePath" }
    $root=[IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if (-not [IO.Directory]::Exists($root)) { throw "Workspace does not exist: $root" }
    $target=[IO.Path]::GetFullPath([IO.Path]::Combine($root,$RelativePath))
    $comparison=if($IsWindows){[StringComparison]::OrdinalIgnoreCase}else{[StringComparison]::Ordinal}
    if (-not $target.StartsWith($root+[IO.Path]::DirectorySeparatorChar,$comparison)) { throw 'Path must be below the workspace root.' }
    $cursor=$target
    while ($cursor -and ($cursor.Length -ge $root.Length)) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked workspace path is not supported: $cursor" }
        }
        if ($cursor -eq $root) { break }
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
    return $target
}
function Get-GuideSelection {
    param([System.Collections.IDictionary]$Policy,[string]$GuideId,[string]$EditionId)
    $guides=@($Policy.guides | Where-Object { $_.id -ceq $GuideId })
    if ($guides.Count -ne 1) { throw "Select exactly one declared guide: $GuideId" }
    $editions=@($guides[0].editions | Where-Object { $_.id -ceq $EditionId })
    if ($editions.Count -ne 1) { throw "Select exactly one declared edition: $GuideId/$EditionId" }
    [pscustomobject]@{Guide=$guides[0];Edition=$editions[0];RelativePath="$($guides[0].contentRoot)/$($editions[0].path)"}
}
function Read-GuideDocument {
    param([string]$Path)
    Import-Module powershell-yaml -MinimumVersion 0.4.12 -ErrorAction Stop
    $raw=[IO.File]::ReadAllText($Path)
    $match=[regex]::Match($raw,'\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)(?<body>.*)\z',[Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) { throw "Expected YAML front matter: $Path" }
    $metadata=ConvertFrom-Yaml $match.Groups['yaml'].Value -ErrorAction Stop
    if ($metadata -isnot [System.Collections.IDictionary]) { throw "Expected mapping front matter: $Path" }
    [pscustomobject]@{Metadata=$metadata;Yaml=$match.Groups['yaml'].Value;Body=$match.Groups['body'].Value}
}
function New-GuideFile {
    param([string]$Path,[string]$Content)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $bytes=[Text.UTF8Encoding]::new($false).GetBytes($Content);$stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}
