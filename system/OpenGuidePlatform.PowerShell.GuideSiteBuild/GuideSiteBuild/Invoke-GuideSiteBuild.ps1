function Invoke-GuideSiteBuild {
    [CmdletBinding()]
    param(
        [ValidateSet('All','Prepare','Build','Validate','Serve','Deploy','Verify','Dependencies')][string]$Stage='All',
        [ValidateSet('auto','local','canary','preview','production')][string]$Target='auto',
        [string]$WorkspaceRoot=$PWD,[string]$PolicyPath,[string]$SourcePath='site',
        [string]$OutputPath,[string]$Version,
        [string]$DeliveryContextPath,[int]$PullRequestNumber,[string]$BaseUrl,[string]$DeploymentUrl,[string]$DeploymentEnvironment,[switch]$Deploy,[string]$DeploymentAdapter
    )
    $ErrorActionPreference='Stop'
    if(-not $Version){
        $metadata=Join-Path (Split-Path (Split-Path $script:GuideBuildModuleRoot -Parent) -Parent) 'platform.json'
        $Version=if(Test-Path -LiteralPath $metadata){(Get-Content $metadata -Raw|ConvertFrom-Json).version}else{'0.0.0-local'}
    }
    if(-not $OutputPath){$OutputPath='.processing/guidesite/'+[guid]::NewGuid().ToString('N')}
    if($Stage -eq 'Dependencies'){Install-GuideBuildDependencies -WorkspaceRoot $WorkspaceRoot -Deployment:$Deploy;return}
    $contextPath=Join-Path $WorkspaceRoot "$OutputPath/delivery-context.json"
    $delivery=$null
    if($DeliveryContextPath){$contextPath=Join-Path $WorkspaceRoot $DeliveryContextPath}
    if($Target -eq 'auto' -or $DeliveryContextPath){
        if(-not $DeliveryContextPath -and $Stage -in @('All','Prepare','Serve')){
            $delivery=Resolve-GuideDeliveryContext -WorkspaceRoot $WorkspaceRoot -PullRequestNumber $PullRequestNumber -BaseUrl $BaseUrl -DeploymentEnvironment $DeploymentEnvironment
        }else{
            $delivery=Get-Content $contextPath -Raw|ConvertFrom-Json
            $commit=(& git -C $WorkspaceRoot rev-parse HEAD).Trim()
            if($delivery.sourceCommit -cne $commit){throw 'Prepared delivery context belongs to another commit. Rerun Prepare.'}
        }
        $Target=$delivery.target;$BaseUrl=$delivery.baseUrl;$DeploymentEnvironment=$delivery.deploymentEnvironment
        if(-not $DeploymentUrl){$DeploymentUrl=$BaseUrl}
    }
    if($Deploy -and $Stage -ne 'All'){throw '-Deploy enables deployment after an All run. Use the Deploy operation for existing validated output.'}
    if(($Deploy -or $Stage -eq 'Deploy') -and $Target -eq 'local'){throw 'Deployment requires an explicit preview or production target.'}
    if($Stage -eq 'Deploy'){
        & "$script:GuideBuildModuleRoot/GuideSiteBuild/Confirm-GuideSiteDeployment.ps1" -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -Target $Target -Version $Version
        $commit=(& git -C $WorkspaceRoot rev-parse HEAD).Trim()
        return Invoke-GuideArtifactDeployment -DeploymentRoot (Join-Path $WorkspaceRoot $OutputPath) -WorkspaceRoot $WorkspaceRoot -SourceCommit $commit -Target $Target -DeploymentEnvironment $DeploymentEnvironment -DeploymentAdapter $DeploymentAdapter -ExpectedUrl $DeploymentUrl
    }
    if($Stage -eq 'Verify'){
        if(-not $PolicyPath){$PolicyPath="$OutputPath/discovered-site.json"}
        if(-not $DeploymentUrl -and (Test-Path (Join-Path $WorkspaceRoot "$OutputPath/deployment.json"))){$DeploymentUrl=(Get-Content (Join-Path $WorkspaceRoot "$OutputPath/deployment.json") -Raw|ConvertFrom-Json).url}
        if([string]::IsNullOrWhiteSpace($DeploymentUrl)){throw 'Verify requires deployment.json or the actual deployment URL returned by the hosting adapter.'}
        & "$script:GuideBuildModuleRoot/GuideSiteBuild/Verify-GuideSiteDeployment.ps1" -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -PolicyPath $PolicyPath -DeploymentUrl $DeploymentUrl -Target $Target -Version $Version
        return
    }
    & "$script:GuideBuildModuleRoot/GuideSiteBuild/Build-GuideSite.ps1" -Stage $Stage -SourcePath $SourcePath -DeliveryContext $delivery -SiteVersion $(if($delivery){$delivery.siteVersion}else{$null}) -BaseUrl $BaseUrl -Target $Target -WorkspaceRoot $WorkspaceRoot -PolicyPath $PolicyPath -OutputPath $OutputPath -Version $Version
    if($Stage -eq 'All' -and $Deploy){
        $result=Invoke-GuideSiteBuild -Stage Deploy -Target $Target -WorkspaceRoot $WorkspaceRoot -PolicyPath $PolicyPath -OutputPath $OutputPath -Version $Version -DeploymentEnvironment $DeploymentEnvironment -DeploymentAdapter $DeploymentAdapter -DeploymentUrl $DeploymentUrl
        Invoke-GuideSiteBuild -Stage Verify -Target $Target -WorkspaceRoot $WorkspaceRoot -PolicyPath $PolicyPath -OutputPath $OutputPath -Version $Version -DeploymentUrl $result.url
    }
}
