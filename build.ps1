#Requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('Platform','GuideSite')][string]$Product='Platform',
    [ValidateSet('All','Prepare','Build','Package','Release','Validate','Serve','Deploy','Verify')][string]$Stage='All',
    [ValidateSet('local','preview','production')][string]$Target='local',
    [string]$WorkspaceRoot=$PSScriptRoot,
    [string]$PolicyPath,
    [string]$OutputPath,
    [string]$Version='0.0.0-local',
    [string]$BaseUrl,[string]$ReleaseTag,[string]$DeploymentUrl,[string]$DeploymentEnvironment,
    [switch]$Versions
)
$ErrorActionPreference='Stop'
if($Versions){
    "PowerShell $($PSVersionTable.PSVersion)"
    foreach($tool in @('hugo','go','pandoc','xelatex')){
        $command=Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
        if(-not $command){"${tool}: unavailable";continue}
        $argument=if($tool -in @('hugo','go')){'version'}else{'--version'}
        $lines=@(& $command.Source $argument 2>&1)
        if($LASTEXITCODE -ne 0){"${tool}: version query failed ($LASTEXITCODE)";continue}
        $version=$lines|Where-Object {-not [string]::IsNullOrWhiteSpace([string]$_)}|Select-Object -First 1
        "${tool}: $version"
    }
    return
}
if(-not $OutputPath){$OutputPath='.processing/'+$Product.ToLowerInvariant()+'/'+[guid]::NewGuid().ToString('N')}
if($Product -eq 'GuideSite'){
    if(-not $PolicyPath){throw 'GuideSite requires a reviewed site policy (-PolicyPath).'}
    if($Stage -in @('Package','Release')){throw 'GuideSite produces a validated site artifact, not a platform release.'}
    if($Stage -eq 'Deploy'){
        if($Target -eq 'local' -or ($Target -ne 'production' -and [string]::IsNullOrWhiteSpace($DeploymentEnvironment))){throw 'Preview deployment requires an explicit named hosting environment; local builds cannot deploy.'}
        & "$PSScriptRoot/.build/Confirm-GuideSiteDeployment.ps1" -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -Target $Target -Version $Version
        return
    }
    if($Stage -eq 'Verify'){
        if([string]::IsNullOrWhiteSpace($DeploymentUrl)){throw 'Verify requires the actual deployment URL returned by the hosting adapter.'}
        & "$PSScriptRoot/.build/Verify-GuideSiteDeployment.ps1" -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -PolicyPath $PolicyPath -DeploymentUrl $DeploymentUrl -Target $Target -Version $Version
        return
    }
    & "$PSScriptRoot/.build/Build-GuideSite.ps1" -Stage $Stage -BaseUrl $BaseUrl -Target $Target -WorkspaceRoot $WorkspaceRoot -PolicyPath $PolicyPath -OutputPath $OutputPath -Version $Version
}else{
    if($Stage -in @('Serve','Deploy','Verify')){throw 'Serve, Deploy and Verify belong to GuideSite; specify -Product GuideSite and its policy.'}
    if($Stage -in @('All','Prepare')){
        Import-Module "$PSScriptRoot/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
        Get-GuideHugoToolchain
    }
    if($Stage -in @('All','Build')){
        & "$PSScriptRoot/.build/Test-PlatformContracts.ps1"
        & "$PSScriptRoot/.build/Test-PlatformCore.ps1"
        & "$PSScriptRoot/.build/Test-HugoTranslationProbe.ps1"
    }
    if($Stage -in @('All','Package')){
        & "$PSScriptRoot/.build/Package-OpenGuidePlatform.ps1" -OutputPath $OutputPath -Version $Version
    }
    if($Stage -eq 'Release'){
        & "$PSScriptRoot/.build/Publish-PlatformPreviewRelease.ps1" -OutputPath $OutputPath
    }
    if($Stage -in @('All','Validate')){
        if($ReleaseTag){
            $commit=(& git -C $PSScriptRoot rev-parse HEAD).Trim()
            if($LASTEXITCODE -ne 0){throw 'Cannot resolve platform commit.'}
            & "$PSScriptRoot/.build/Restore-OpenGuidePlatform.ps1" -ReleaseTag $ReleaseTag -ExpectedCommit $commit -OutputPath $OutputPath
        }else{
            & "$PSScriptRoot/.build/Test-OpenGuidePlatformPackage.ps1" -OutputPath $OutputPath
        }
    }
}
