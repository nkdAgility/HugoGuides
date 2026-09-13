function Get-GuideBuildContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('pull_request','push','merge_group','workflow_dispatch')][string]$EventName,
        [AllowEmptyString()][string]$PreReleaseLabel='',
        [ValidateRange(0,2147483647)][int]$PullRequestNumber=0,
        [ValidatePattern('^[A-Za-z0-9-]*$')][string]$ProductionEnvironment='production'
    )
    # A PR or merge queue candidate cannot select production from its version label.
    if($EventName -eq 'pull_request'){
        if($PullRequestNumber -lt 1){throw 'A pull request build requires its positive PR number.'}
        return [pscustomobject]@{Ring='Canary';Target='preview';DeploymentEnvironment="canary-$PullRequestNumber"}
    }
    if($EventName -eq 'merge_group'){
        return [pscustomobject]@{Ring='Canary';Target='preview';DeploymentEnvironment='canary-merge-group'}
    }
    switch -CaseSensitive ($PreReleaseLabel){
        '' { [pscustomobject]@{Ring='Production';Target='production';DeploymentEnvironment=if($ProductionEnvironment -eq 'production'){''}else{$ProductionEnvironment}} }
        'Preview' { [pscustomobject]@{Ring='Preview';Target='preview';DeploymentEnvironment='preview'} }
        default { [pscustomobject]@{Ring='Canary';Target='preview';DeploymentEnvironment='canary'} }
    }
}