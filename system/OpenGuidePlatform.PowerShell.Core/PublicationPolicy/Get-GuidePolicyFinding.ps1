function Get-GuidePolicyFinding {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Policy)
    $guideIds=@($Policy.guides | ForEach-Object { $_.id })
    foreach ($group in @($guideIds | Group-Object | Where-Object Count -gt 1)) { [pscustomobject]@{Code='DUPLICATE_GUIDE';Subject=$group.Name} }
    foreach($environment in $Policy.publication.environments){
        foreach($id in $environment.excludedGuides){
            $selected=@($Policy.guides|Where-Object id -CEQ $id)
            if($selected.Count -ne 1){[pscustomobject]@{Code='UNKNOWN_EXCLUDED_GUIDE';Subject="$($environment.name)/$id"}}
            elseif(-not $selected[0].Contains('artifactPrefixes') -or -not @($selected[0].artifactPrefixes).Count){[pscustomobject]@{Code='EXCLUDED_GUIDE_PATHS_REQUIRED';Subject="$($environment.name)/$id"}}
        }
    }
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
        } elseif($rule.Contains('artifactPrefixes') -and @($rule.artifactPrefixes).Count){
            [pscustomobject]@{Code='PUBLICATION_ARTIFACT_CHECK_PENDING';Subject=$rule.id;Severity='info';Reason='Validate must prove the declared guide/edition artifact prefixes are absent for the selected target. Prepare is not artifact approval.'}
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

function Get-GuideForbiddenPaths {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Collections.IDictionary]$Policy,[Parameter(Mandatory)][string]$Target)
    $rules=@($Policy.publication.permanentExclusions|Where-Object environment -CEQ $Target)
    foreach($environment in $Policy.publication.environments|Where-Object name -CEQ $Target){
        foreach($language in $environment.excludedLanguages){$rules+=@{subject='language';id=$language}}
        foreach($id in $environment.excludedGuides){
            $guide=@($Policy.guides|Where-Object id -CEQ $id)
            if($guide.Count -ne 1 -or -not $guide[0].Contains('artifactPrefixes')){throw "Declare artifactPrefixes on excluded guide $id."}
            $rules+=@{subject='guide';id=$id;artifactPrefixes=$guide[0].artifactPrefixes}
        }
    }
    foreach($rule in $rules){
        if($rule.subject -eq 'language'){$rule.id;continue}
        if(-not $rule.Contains('artifactPrefixes') -or -not @($rule.artifactPrefixes).Count){throw "Declare artifactPrefixes for excluded $($rule.subject) $($rule.id); no public paths are inferred from content IDs."}
        foreach($prefix in $rule.artifactPrefixes){
            if([string]::IsNullOrWhiteSpace($prefix) -or $prefix.StartsWith('/') -or $prefix -match '[\\:?#%]' -or @($prefix.Split('/')|Where-Object {$_ -in @('..','.','')}).Count){throw "Unsafe exclusion prefix: $prefix"}
            $prefix
        }
    }
}
