function Invoke-GuideSiteBuild {
    [CmdletBinding()]
    param(
        [ValidateSet('All','Prepare','Build','Validate','Serve','Deploy','Verify','Dependencies')][string]$Stage='All',
        [ValidateSet('local','preview','production')][string]$Target='local',
        [string]$WorkspaceRoot=$PWD,[Parameter(Mandatory)][string]$PolicyPath,
        [string]$OutputPath,[string]$Version,
        [string]$BaseUrl,[string]$DeploymentUrl,[string]$DeploymentEnvironment,[switch]$Deploy,[string]$DeploymentAdapter
    )
    $ErrorActionPreference='Stop'
    if(-not $Version){
        $metadata=Join-Path (Split-Path (Split-Path $script:GuideBuildModuleRoot -Parent) -Parent) 'platform.json'
        $Version=if(Test-Path -LiteralPath $metadata){(Get-Content $metadata -Raw|ConvertFrom-Json).version}else{'0.0.0-local'}
    }
    if(-not $OutputPath){$OutputPath='.processing/guidesite/'+[guid]::NewGuid().ToString('N')}
    if(-not $PolicyPath){throw 'GuideSite requires a reviewed site policy (-PolicyPath).'}
    if($Stage -eq 'Dependencies'){Install-GuideBuildDependencies -WorkspaceRoot $WorkspaceRoot -Deployment:$Deploy;return}
    if($Deploy -and $Stage -ne 'All'){throw '-Deploy enables deployment after an All run. Use the Deploy operation for existing validated output.'}
    if(($Deploy -or $Stage -eq 'Deploy') -and $Target -eq 'local'){throw 'Deployment requires an explicit preview or production target.'}
    if($Stage -eq 'Deploy'){
        & "$script:GuideBuildModuleRoot/GuideSiteBuild/Confirm-GuideSiteDeployment.ps1" -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -Target $Target -Version $Version
        $commit=(& git -C $WorkspaceRoot rev-parse HEAD).Trim()
        return Invoke-GuideArtifactDeployment -DeploymentRoot (Join-Path $WorkspaceRoot $OutputPath) -WorkspaceRoot $WorkspaceRoot -SourceCommit $commit -Target $Target -DeploymentEnvironment $DeploymentEnvironment -DeploymentAdapter $DeploymentAdapter -ExpectedUrl $DeploymentUrl
    }
    if($Stage -eq 'Verify'){
        if(-not $DeploymentUrl -and (Test-Path (Join-Path $WorkspaceRoot "$OutputPath/deployment.json"))){$DeploymentUrl=(Get-Content (Join-Path $WorkspaceRoot "$OutputPath/deployment.json") -Raw|ConvertFrom-Json).url}
        if([string]::IsNullOrWhiteSpace($DeploymentUrl)){throw 'Verify requires deployment.json or the actual deployment URL returned by the hosting adapter.'}
        & "$script:GuideBuildModuleRoot/GuideSiteBuild/Verify-GuideSiteDeployment.ps1" -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -PolicyPath $PolicyPath -DeploymentUrl $DeploymentUrl -Target $Target -Version $Version
        return
    }
    & "$script:GuideBuildModuleRoot/GuideSiteBuild/Build-GuideSite.ps1" -Stage $Stage -BaseUrl $BaseUrl -Target $Target -WorkspaceRoot $WorkspaceRoot -PolicyPath $PolicyPath -OutputPath $OutputPath -Version $Version
    if($Stage -eq 'All' -and $Deploy){
        $result=Invoke-GuideSiteBuild -Stage Deploy -Target $Target -WorkspaceRoot $WorkspaceRoot -PolicyPath $PolicyPath -OutputPath $OutputPath -Version $Version -DeploymentEnvironment $DeploymentEnvironment -DeploymentAdapter $DeploymentAdapter -DeploymentUrl $DeploymentUrl
        Invoke-GuideSiteBuild -Stage Verify -Target $Target -WorkspaceRoot $WorkspaceRoot -PolicyPath $PolicyPath -OutputPath $OutputPath -Version $Version -DeploymentUrl $result.url
    }
}
