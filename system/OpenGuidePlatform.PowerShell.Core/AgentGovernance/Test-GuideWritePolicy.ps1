function Test-GuideWritePolicy {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Policy,[Parameter(Mandatory)][string]$RelativePath)
    $path=$RelativePath.TrimEnd('/')
    $protected=@($Policy.protectedPaths)
    foreach ($guide in $Policy.guides) {
        if ($guide.protectSource) { $protected += $guide.contentRoot }
        foreach ($edition in $guide.editions) {
            foreach ($translation in $edition.translations) {
                foreach ($download in $translation.downloads) {
                    if ($download.handling -in @('supplied','protected')) { $protected += "$($guide.contentRoot)/$($edition.path)/$($download.path)" }
                }
            }
        }
    }
    foreach ($entry in $protected) {
        $prefix=$entry.TrimEnd('/')
        if ($path.Equals($prefix,[StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith($prefix+'/',[StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{Allowed=$false;Code='PROTECTED_RESOURCE';Path=$RelativePath;Reason="The supplied policy protects $entry."}
        }
    }
    [pscustomobject]@{Allowed=$true;Code='WRITE_WITHIN_SUPPLIED_POLICY';Path=$RelativePath;Reason='This checks supplied policy, not external authority or filesystem containment.'}
}
function Assert-GuideWriteAllowed {
    param([System.Collections.IDictionary]$Policy,[string]$RelativePath)
    $decision=Test-GuideWritePolicy -Policy $Policy -RelativePath $RelativePath
    if (-not $decision.Allowed) { throw "$($decision.Code): $($decision.Reason)" }
}
