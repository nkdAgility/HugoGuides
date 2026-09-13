#Requires -Version 7.4
<#
.SYNOPSIS
Captures unmodified remote-main source and Hugo build baselines in an isolated directory.
.DESCRIPTION
Reads local Git repositories after the operator fetches their remotes. Does not switch
consumer branches, edit consumer worktrees, deploy, or approve observed behaviour.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$HugoCommand = 'hugo',
    [string]$SourceRef = 'origin/main'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$destination = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $destination) { throw "Use a new output directory: $destination" }
$names = @('HugoGuides', 'KanbanGuides', 'the-safe-delusion', 'ScrumGuide-ExpansionPack')
foreach ($name in $names) {
    $source = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $name))
    if ($destination.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and $name -ne 'HugoGuides') {
        throw 'Baseline output must not be inside a consumer worktree.'
    }
}
New-Item -ItemType Directory -Path $destination | Out-Null
$hugoVersion = (& $HugoCommand version | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Hugo version check failed.' }
$goVersion = (& go version | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Go version check failed.' }
$records = [Collections.Generic.List[object]]::new()
foreach ($name in $names) {
    $source = Join-Path $RepositoryRoot $name
    $commit = (& git -C $source rev-parse "$SourceRef^{commit}" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Cannot resolve $SourceRef in $name" }
    $zip = Join-Path $destination "$name.zip"
    & git -C $source archive --format=zip "--output=$zip" $commit
    if ($LASTEXITCODE -ne 0) { throw "Archive failed: $name" }
    $snapshot = Join-Path $destination $name
    Expand-Archive -LiteralPath $zip -DestinationPath $snapshot
    $inventory = @(Get-ChildItem -LiteralPath $snapshot -Recurse -File | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($snapshot, $_.FullName).Replace('\','/'); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); bytes = $_.Length }
    })
    $inventory | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $destination "$name.source.json")
    $records.Add([ordered]@{ repository = $name; commit = $commit; sourceFiles = $inventory.Count; builds = @() })
}
# Archive all repositories first so the example's existing sibling replacements resolve.
$previousEnvironment = $env:HUGO_ENVIRONMENT
$previousHugoEnv = $env:HUGO_ENV
try {
    foreach ($record in $records) {
        $snapshot = Join-Path $destination $record.repository
        $sourceDirectory = if (Test-Path (Join-Path $snapshot 'examples/reference-guide-site/hugo.yaml')) { 'examples/reference-guide-site' } else { 'site' }
        foreach ($ring in @('local','preview','production')) {
            $config = "hugo.yaml,hugo.$ring.yaml"
            $environment = if ($ring -eq 'local') { 'development' } else { $ring }
            $env:HUGO_ENVIRONMENT = $environment
            $env:HUGO_ENV = $environment
            $artifact = Join-Path $destination "artifacts/$($record.repository)/$ring"
            $logPath = Join-Path $destination "$($record.repository).$ring.log"
            Push-Location $snapshot
            try {
                & $HugoCommand --source $sourceDirectory --config $config --environment $environment --destination $artifact *> $logPath
                $buildExit = $LASTEXITCODE
            } finally { Pop-Location }
            $errors = @(Select-String -LiteralPath $logPath -Pattern '^ERROR')
            $warnings = @(Select-String -LiteralPath $logPath -Pattern '^WARN')
            $files = @(if (Test-Path -LiteralPath $artifact) {
                Get-ChildItem -LiteralPath $artifact -Recurse -File | Sort-Object FullName | ForEach-Object {
                    [ordered]@{ path = [IO.Path]::GetRelativePath($artifact, $_.FullName).Replace('\','/'); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); bytes = $_.Length }
                }
            })
            $files | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $destination "$($record.repository).$ring.artifacts.json")
            $record.builds += [ordered]@{
                ring = $ring; config = $config; environment = $environment
                exitCode = $buildExit; errors = $errors.Count; warnings = $warnings.Count
                files = $files.Count; passed = ($buildExit -eq 0 -and $errors.Count -eq 0)
            }
            Write-Host "$($record.repository) $ring : exit=$buildExit errors=$($errors.Count) files=$($files.Count)"
        }
    }
} finally {
    $env:HUGO_ENVIRONMENT = $previousEnvironment
    $env:HUGO_ENV = $previousHugoEnv
}
[ordered]@{
    capturedAt = [DateTimeOffset]::UtcNow.ToString('o')
    sourceRef = $SourceRef; hugo = $hugoVersion; go = $goVersion
    powerShell = $PSVersionTable.PSVersion.ToString()
    scope = 'Raw Hugo builds from archived source; not deployed-artifact or visual approval; CI token substitution and hosting packaging are not reproduced.'
    repositories = @($records.ToArray())
} | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $destination 'baseline.json')
if (@($records | Where-Object { @($_.builds | Where-Object { -not $_.passed }).Count -gt 0 }).Count -gt 0) {
    throw "Baseline contains failed builds. See $destination/baseline.json and per-build logs."
}
