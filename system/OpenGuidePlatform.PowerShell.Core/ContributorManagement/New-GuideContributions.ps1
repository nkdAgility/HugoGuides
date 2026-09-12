function New-GuideContributions {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][System.Collections.IDictionary]$Policy,[Parameter(Mandatory)][string]$GuideId,[Parameter(Mandatory)][object[]]$Contributors)
    if (@($Policy.guides | Where-Object { $_.id -ceq $GuideId }).Count -ne 1) { throw 'Select one declared guide.' }
    $relative="$($Policy.wrapper.sourcePath)/data/contributions/$GuideId.yml"
    $path=Resolve-GuideWorkspacePath $WorkspaceRoot $relative
    Assert-GuideWriteAllowed $Policy $relative
    if ([IO.File]::Exists($path)) { throw 'Contributor file exists; review and edit it rather than replacing it.' }
    foreach ($contributor in $Contributors) {
        if ([string]::IsNullOrWhiteSpace($contributor.name) -or $contributor.role -notin @('creator','contributor','involved')) { throw 'Each contributor needs a name and a supported role.' }
    }
    Import-Module powershell-yaml -RequiredVersion 0.4.12 -ErrorAction Stop
    $yaml=ConvertTo-Yaml -Data $Contributors
    if ($PSCmdlet.ShouldProcess($path,'Create guide contributor data')) { New-GuideFile $path $yaml;[pscustomobject]@{Status='created';Path=$relative;Count=$Contributors.Count} }
}
