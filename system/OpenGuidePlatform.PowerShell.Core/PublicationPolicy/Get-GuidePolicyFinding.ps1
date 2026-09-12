function Get-GuidePolicyFinding {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Policy)
    $guideIds=@($Policy.guides | ForEach-Object { $_.id })
    foreach ($group in @($guideIds | Group-Object | Where-Object Count -gt 1)) { [pscustomobject]@{Code='DUPLICATE_GUIDE';Subject=$group.Name} }
    foreach ($guide in $Policy.guides) {
        if ($guide.relationship.kind -eq 'extension' -and $guide.relationship.parentGuideId -notin $guideIds) { [pscustomobject]@{Code='UNKNOWN_PARENT_GUIDE';Subject=$guide.id} }
        $seen=@{};$node=$guide
        while ($node.relationship.kind -eq 'extension') {
            if ($seen.ContainsKey($node.id)) { [pscustomobject]@{Code='GUIDE_RELATIONSHIP_CYCLE';Subject=$guide.id};break }
            $seen[$node.id]=$true
            $next=@($Policy.guides | Where-Object { $_.id -eq $node.relationship.parentGuideId })
            if ($next.Count -ne 1) { break };$node=$next[0]
        }
        foreach ($group in @($guide.editions | Group-Object id | Where-Object Count -gt 1)) { [pscustomobject]@{Code='DUPLICATE_EDITION';Subject="$($guide.id)/$($group.Name)"} }
        foreach ($edition in $guide.editions) {
            foreach ($group in @($edition.translations | Group-Object language | Where-Object Count -gt 1)) { [pscustomobject]@{Code='DUPLICATE_TRANSLATION';Subject="$($guide.id)/$($edition.id)/$($group.Name)"} }
            foreach ($translation in $edition.translations) {
                $seen=@{};$node=$translation
                while ($node.intent -eq 'fallback') {
                    if ($seen.ContainsKey($node.language)) { [pscustomobject]@{Code='FALLBACK_CYCLE';Subject="$($guide.id)/$($edition.id)/$($translation.language)"};break }
                    $seen[$node.language]=$true
                    $next=@($edition.translations | Where-Object { $_.language -eq $node.fallbackLanguage })
                    if ($next.Count -ne 1) { [pscustomobject]@{Code='UNKNOWN_FALLBACK_LANGUAGE';Subject="$($guide.id)/$($edition.id)/$($node.language)"};break };$node=$next[0]
                }
            }
        }
    }
}
function Test-GuidePublicationPolicy {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Policy,[Parameter(Mandatory)][System.Collections.IDictionary]$EffectiveProduction)
    foreach ($rule in $Policy.publication.permanentExclusions) {
        if ($rule.environment -ne 'production') { continue }
        if ($rule.subject -eq 'language') {
            $languages=$EffectiveProduction['languages']
            if ($null -eq $languages -or -not $languages.Contains($rule.id)) {
                [pscustomobject]@{Code='PRODUCTION_LANGUAGE_STATE_UNKNOWN';Subject=$rule.id;Severity='blocker';Reason='A missing language observation is not proof of exclusion.'}
            } elseif ($languages[$rule.id]['disabled'] -ne $true) {
                [pscustomobject]@{Code='PERMANENT_LANGUAGE_ENABLED';Subject=$rule.id;Severity='blocker';Reason=$rule.reason}
            }
        } else {
            [pscustomobject]@{Code='PUBLICATION_EVIDENCE_REQUIRED';Subject=$rule.id;Severity='blocker';Reason='Guide/edition exclusion requires effective artifact evidence from Validate.'}
        }
    }
}
function Import-GuidePolicy {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $raw=[IO.File]::ReadAllText([IO.Path]::GetFullPath($Path))
    if (-not (Test-Json -Json $raw -SchemaFile (Join-Path $script:CoreRoot 'Contracts/site-policy.schema.json') -ErrorAction Stop)) { throw 'Invalid site policy.' }
    $policy=ConvertFrom-Json -InputObject $raw -AsHashtable
    $findings=@(Get-GuidePolicyFinding -Policy $policy)
    if ($findings.Count) { throw "Invalid policy relationships: $($findings.Code -join ', ')" }
    return $policy
}
