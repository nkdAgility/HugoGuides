#Requires -Version 7.4
[CmdletBinding(DefaultParameterSetName='Release')]
param(
    [Parameter(ParameterSetName='Workflow')][switch]$FromWorkflow,
    [Parameter(ParameterSetName='Release')][ValidatePattern('^(?:v[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?)?$')][string]$ReleaseTag,
    [Parameter(Mandatory,ParameterSetName='Candidate')][uri]$PackageUrl,
    [Parameter(Mandatory,ParameterSetName='Candidate')][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$PackageSha256,
    [Parameter(Mandatory,ParameterSetName='Candidate')][ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')][string]$ExpectedVersion,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedCommit,
    [Parameter(Mandatory)][string]$OutputPath
)
$arguments=@{}+$PSBoundParameters
if($arguments.ContainsKey('ReleaseTag')){$arguments.PlatformRelease=$arguments.ReleaseTag;$arguments.Remove('ReleaseTag')}
$null=& "$PSScriptRoot/../system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $PWD @arguments
