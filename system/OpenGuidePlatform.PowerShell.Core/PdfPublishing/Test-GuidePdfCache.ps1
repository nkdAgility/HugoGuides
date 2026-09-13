function Test-GuidePdfCache {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$Receipt,[Parameter(Mandatory)][object[]]$Toolchain,[string]$EnvironmentSha256)
    # The environment digest must cover the approved TeX packages, fonts, templates
    # and indirect resources. Without it these visible fingerprints are incomplete.
    if ($EnvironmentSha256 -notmatch '^[a-fA-F0-9]{64}$') { return [pscustomobject]@{Reusable=$false;Reason='ENVIRONMENT_EVIDENCE_REQUIRED'} }
    if (@($Toolchain | Where-Object { -not $_.Available }).Count) { return [pscustomobject]@{Reusable=$false;Reason='TOOLCHAIN_UNAVAILABLE'} }
    foreach($tool in @('pandoc','xelatex')) {
        if (@($Toolchain | Where-Object Tool -eq $tool).Count -ne 1) { return [pscustomobject]@{Reusable=$false;Reason='TOOLCHAIN_UNAVAILABLE'} }
    }
    foreach($input in $Plan.Fingerprints) {
        $path=Resolve-GuideWorkspacePath $Plan.WorkspaceRoot $input.Path
        if (-not [IO.File]::Exists($path) -or (Get-FileHash -LiteralPath $path).Hash -ne $input.Sha256) { return [pscustomobject]@{Reusable=$false;Reason='INPUT_EVIDENCE_CHANGED'} }
    }
    $expected=Get-GuidePdfCacheKey $Plan $Toolchain $EnvironmentSha256
    if ($null -eq $Receipt -or -not $Receipt.PSObject.Properties['CacheKey'] -or $Receipt.CacheKey -ne $expected) { return [pscustomobject]@{Reusable=$false;Reason='INPUT_EVIDENCE_CHANGED'} }
    if (-not [IO.File]::Exists($Plan.Output) -or -not $Receipt.PSObject.Properties['Sha256'] -or (Get-FileHash -LiteralPath $Plan.Output).Hash -ne $Receipt.Sha256) { return [pscustomobject]@{Reusable=$false;Reason='OUTPUT_CHANGED_OR_MISSING'} }
    [pscustomobject]@{Reusable=$true;Reason='MATCHING_EVIDENCE'}
}
function Get-GuidePdfCacheKey {
    param($Plan,[object[]]$Toolchain,[string]$EnvironmentSha256)
    $evidence=[ordered]@{Generator=(Get-FileHash -LiteralPath (Join-Path $script:CoreRoot 'PdfPublishing/Get-GuidePdfPlan.ps1')).Hash;Inputs=$Plan.Fingerprints;Policy=$Plan.ConfigurationSha256;Arguments=$Plan.Arguments;Fonts=$Plan.Fonts;Tools=$Toolchain;Environment=$EnvironmentSha256;Output=$Plan.RelativeOutput}
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($evidence|ConvertTo-Json -Depth 100 -Compress)))).ToLowerInvariant()
}