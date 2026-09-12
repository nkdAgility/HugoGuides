function Get-GuideLanguage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FileName,[Parameter(Mandatory)][ValidatePattern('^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$')][string]$DefaultLanguage)
    if ($FileName -ceq 'index.md') { return $DefaultLanguage }
    if ($FileName -cmatch '^index\.([A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*)\.md$') { return $Matches[1] }
    throw "Unsupported guide filename: $FileName"
}
