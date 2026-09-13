function Get-GuideTranslationState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('web','pdf-only','fallback','scaffold','excluded')][string]$Intent,[Parameter(Mandatory)][ValidateSet('populated','empty','missing')][string]$Body,[bool]$HasDownload=$false,[bool]$FallbackAvailable=$false)
    $state=$Intent;$code=$null
    switch ($Intent) {
        'web' { if ($Body -ne 'populated') {$state='unknown';$code='WEB_BODY_MISSING'} }
        'pdf-only' { if (-not $HasDownload) {$state='unknown';$code='PDF_RESOURCE_MISSING'} }
        'fallback' { if (-not $FallbackAvailable) {$state='unknown';$code='FALLBACK_UNAVAILABLE'} }
        'scaffold' { if ($Body -eq 'populated') {$state='unknown';$code='POPULATED_SCAFFOLD_REVIEW_INTENT'} }
    }
    [pscustomobject]@{State=$state;Body=$Body;FindingCode=$code;Ready=($state -in @('web','pdf-only','fallback','excluded'))}
}
