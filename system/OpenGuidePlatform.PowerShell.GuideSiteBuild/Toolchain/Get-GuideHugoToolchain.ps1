function Invoke-GuideHugoVersion {
    $command=Get-Command hugo -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $output=@(& $command.Source version 2>&1)
    if($LASTEXITCODE -ne 0){throw "Hugo version check failed with exit code $LASTEXITCODE."}
    $output -join "`n"
}
function Get-GuideHugoToolchain {
    [CmdletBinding()]
    param([version]$MinimumVersion='0.146.0')
    $raw=Invoke-GuideHugoVersion
    if($raw -notmatch '^hugo v(?<version>\d+\.\d+\.\d+)(?<qualifiers>[^\s]*)\s'){
        throw 'Cannot establish the Hugo version from its executable output.'
    }
    $version=[version]$Matches.version
    $qualifiers=$Matches.qualifiers
    if($qualifiers -notmatch '(?:\+|\.)extended(?:\+|\.|$)'){
        throw 'Hugo Extended is required; the detected executable is not an Extended build.'
    }
    if($version -lt $MinimumVersion){throw "Hugo $version is below required minimum $MinimumVersion."}
    [pscustomobject]@{Version=$version.ToString();Extended=$true;Raw=$raw}
}