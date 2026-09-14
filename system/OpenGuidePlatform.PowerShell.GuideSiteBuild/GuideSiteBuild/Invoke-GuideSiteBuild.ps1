function Invoke-GuideSiteBuild {
    [CmdletBinding()]
    param(
        [ValidateSet('All','Prepare','Build','Validate','Serve','Deploy','Verify')][string]$Stage='All',
        [ValidateSet('local','preview','production')][string]$Target='local',
        [string]$WorkspaceRoot=$PWD,[Parameter(Mandatory)][string]$PolicyPath,
        [string]$OutputPath,[string]$Version,
        [string]$BaseUrl,[string]$DeploymentUrl,[string]$DeploymentEnvironment
    )
    $ErrorActionPreference='Stop'
    if(-not $Version){
        $metadata=Join-Path (Split-Path (Split-Path $script:GuideBuildModuleRoot -Parent) -Parent) 'platform.json'
        $Version=if(Test-Path -LiteralPath $metadata){(Get-Content $metadata -Raw|ConvertFrom-Json).version}else{'0.0.0-local'}
    }
    if(-not $OutputPath){$OutputPath='.processing/guidesite/'+[guid]::NewGuid().ToString('N')}
    if(-not $PolicyPath){throw 'GuideSite requires a reviewed site policy (-PolicyPath).'}
    if($Stage -eq 'Deploy'){
        if($Target -eq 'local' -or ($Target -ne 'production' -and [string]::IsNullOrWhiteSpace($DeploymentEnvironment))){throw 'Preview deployment requires an explicit named hosting environment; local builds cannot deploy.'}
        & "$script:GuideBuildModuleRoot/GuideSiteBuild/Confirm-GuideSiteDeployment.ps1" -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -Target $Target -Version $Version
        return
    }
    if($Stage -eq 'Verify'){
        if([string]::IsNullOrWhiteSpace($DeploymentUrl)){throw 'Verify requires the actual deployment URL returned by the hosting adapter.'}
        & "$script:GuideBuildModuleRoot/GuideSiteBuild/Verify-GuideSiteDeployment.ps1" -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -PolicyPath $PolicyPath -DeploymentUrl $DeploymentUrl -Target $Target -Version $Version
        return
    }
    & "$script:GuideBuildModuleRoot/GuideSiteBuild/Build-GuideSite.ps1" -Stage $Stage -BaseUrl $BaseUrl -Target $Target -WorkspaceRoot $WorkspaceRoot -PolicyPath $PolicyPath -OutputPath $OutputPath -Version $Version
}
