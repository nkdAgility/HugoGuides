function Resolve-GuideContributionsPath {
    param([string]$WorkspaceRoot,[System.Collections.IDictionary]$Policy,[string]$GuideId)
    if (@($Policy.guides | Where-Object { $_.id -ceq $GuideId }).Count -ne 1) { throw 'Select one declared guide.' }
    $base="$($Policy.wrapper.sourcePath)/data/contributions/$GuideId"
    $existing=@(foreach($extension in @('yml','yaml')) {
        $relative="$base.$extension"
        $path=Resolve-GuideWorkspacePath $WorkspaceRoot $relative
        if ([IO.File]::Exists($path)) { [pscustomobject]@{Path=$path;Relative=$relative} }
    })
    if ($existing.Count -gt 1) { throw 'Ambiguous contributor files: both .yml and .yaml exist.' }
    if ($existing.Count -eq 1) { return $existing[0] }
    [pscustomobject]@{Path=(Resolve-GuideWorkspacePath $WorkspaceRoot "$base.yml");Relative="$base.yml"}
}
function Update-GuideContributions {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$WorkspaceRoot,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Policy,
        [Parameter(Mandatory)][string]$GuideId,
        [Parameter(Mandatory)][string]$ContributorName,
        [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$CandidateYaml
    )
    $selection=Resolve-GuideContributionsPath $WorkspaceRoot $Policy $GuideId
    Assert-GuideWriteAllowed $Policy $selection.Relative
    if (-not [IO.File]::Exists($selection.Path)) { throw 'Contributor file is missing; use the new-file operation.' }
    $originalBytes=[IO.File]::ReadAllBytes($selection.Path)
    $originalHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($originalBytes))
    if ($originalHash -ne $ExpectedSha256) { throw 'Contributor file changed since review; read and review it again.' }
    Import-Module powershell-yaml -RequiredVersion 0.4.12 -ErrorAction Stop
    $before=ConvertFrom-Yaml ([Text.Encoding]::UTF8.GetString($originalBytes).TrimStart([char]0xFEFF))
    $after=ConvertFrom-Yaml $CandidateYaml
    if ($before -isnot [Collections.IList] -or $after -isnot [Collections.IList]) { throw 'Expected a contributor collection.' }
    if ($before.Count -ne $after.Count -or $before.Count -eq 0) { throw 'An update must preserve the contributor collection.' }
    $selected=0
    for ($i=0;$i -lt $before.Count;$i++) {
        if ($before[$i] -isnot [Collections.IDictionary] -or $after[$i] -isnot [Collections.IDictionary]) { throw 'Expected contributor mappings.' }
        if ($before[$i].name -ceq $ContributorName) {
            $selected++
            if ($after[$i].name -cne $ContributorName -or [string]::IsNullOrWhiteSpace($after[$i].role)) { throw 'Preserve the selected name and supply a role.' }
        } elseif (($before[$i] | ConvertTo-Json -Depth 100 -Compress) -cne ($after[$i] | ConvertTo-Json -Depth 100 -Compress)) {
            throw 'Candidate changes an unselected contributor or contributor order.'
        }
    }
    if ($selected -ne 1) { throw 'Select exactly one existing contributor by name.' }
    $encoding=[Text.UTF8Encoding]::new($false)
    $candidateBytes=$encoding.GetBytes($CandidateYaml)
    $candidateHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($candidateBytes))
    if ($candidateHash -eq $originalHash) { return [pscustomobject]@{Status='unchanged';Path=$selection.Relative;Sha256=$originalHash.ToLowerInvariant()} }
    if ($PSCmdlet.ShouldProcess($selection.Path,"Apply reviewed candidate for contributor $ContributorName")) {
        # Cooperative writer lock plus a second hash check. This is not an OS-level
        # compare-and-swap against editors that ignore the lock.
        $lockPath=$selection.Path+'.update-lock'
        $lock=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $temporary=$selection.Path+'.candidate-'+[guid]::NewGuid().ToString('N')
        try {
            New-GuideFile $temporary $CandidateYaml
            $checked=Resolve-GuideWorkspacePath $WorkspaceRoot $selection.Relative
            Assert-GuideWriteAllowed $Policy $selection.Relative
            if ((Get-FileHash -LiteralPath $checked -Algorithm SHA256).Hash -ne $ExpectedSha256) { throw 'Contributor file changed during preparation; candidate not applied.' }
            [IO.File]::Replace($temporary,$checked,[System.Management.Automation.Language.NullString]::Value)
        } finally {
            try { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
            finally { $lock.Dispose();[IO.File]::Delete($lockPath) }
        }
        [pscustomobject]@{Status='updated';Path=$selection.Relative;PreviousSha256=$originalHash.ToLowerInvariant();Sha256=$candidateHash.ToLowerInvariant()}
    }
}