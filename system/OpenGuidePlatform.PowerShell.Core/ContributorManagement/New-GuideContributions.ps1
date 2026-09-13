function New-GuideContributions {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][System.Collections.IDictionary]$Policy,[Parameter(Mandatory)][string]$GuideId,[Parameter(Mandatory)][object[]]$Contributors)
    $selection=Resolve-GuideContributionsPath $WorkspaceRoot $Policy $GuideId
    $relative=$selection.Relative;$path=$selection.Path
    Assert-GuideWriteAllowed $Policy $relative
    if ([IO.File]::Exists($path)) { throw 'Contributor file exists; review and edit it rather than replacing it.' }
    foreach ($contributor in $Contributors) {
        if ([string]::IsNullOrWhiteSpace($contributor.name) -or [string]::IsNullOrWhiteSpace($contributor.role)) { throw 'Each contributor needs a name and a non-empty role.' }
    }
    Import-Module powershell-yaml -MinimumVersion 0.4.12 -ErrorAction Stop
    $yaml=ConvertTo-Yaml -Data $Contributors
    if ($PSCmdlet.ShouldProcess($path,'Create guide contributor data')) { New-GuideFile $path $yaml;[pscustomobject]@{Status='created';Path=$relative;Count=$Contributors.Count} }
}
