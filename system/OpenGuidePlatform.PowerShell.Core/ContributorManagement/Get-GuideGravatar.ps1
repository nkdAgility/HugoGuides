function Get-GuideGravatar {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Email,[ValidateRange(1,2048)][int]$Size=64)
    $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Email.Trim().ToLowerInvariant()))).ToLowerInvariant()
    [pscustomobject]@{Hash=$hash;HashType='SHA-256';Url="https://www.gravatar.com/avatar/${hash}?s=$Size"}
}
