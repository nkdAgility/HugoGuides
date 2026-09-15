#Requires -Version 7.4
# Remote install/update entry point: irm https://raw.githubusercontent.com/nkdAgility/OpenGuidePlatform/main/bootstrap.ps1 | iex
function Invoke-OpenGuidePlatformBootstrap {
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Install,[switch]$Update,[ValidateSet('preview','stable')][string]$Channel='preview',[string]$ReleaseTag,[string]$WorkspaceRoot=$PWD,[string]$SourcePath='site')
$ErrorActionPreference='Stop'
# The loader is source infrastructure; all adoption behavior comes from the verified release.
$loader=Invoke-RestMethod 'https://raw.githubusercontent.com/nkdAgility/OpenGuidePlatform/main/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1'
$resolve=[scriptblock]::Create($loader)
if(-not $ReleaseTag){
    $settings=& $resolve -WorkspaceRoot $WorkspaceRoot -ReadSettings
    if($settings){
        if(-not $PSBoundParameters.ContainsKey('Channel') -or $settings.platform.version -match '^v[0-9]+(?:\.[0-9]+)?$'){$ReleaseTag=$settings.platform.version}
        if(-not $PSBoundParameters.ContainsKey('Channel')){$Channel=if($settings.platform.ring -eq 'production'){'stable'}else{'preview'}}
    }elseif(-not $PSBoundParameters.ContainsKey('Channel') -and (Test-Path "$WorkspaceRoot/.OpenGuidePlatform/installation.json")){
        $existing=Get-Content "$WorkspaceRoot/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json
        $Channel=$existing.release.channel
    }
}
$package=& $resolve -WorkspaceRoot $WorkspaceRoot -PlatformSource $(if($Channel -eq 'stable'){'Production'}else{'Preview'}) -PlatformRelease $ReleaseTag
Import-Module "$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/OpenGuidePlatform.PowerShell.GuideSiteAdoption.psm1" -Force
Invoke-GuideSiteAdoption -PackageRoot $package -WorkspaceRoot $WorkspaceRoot -SourcePath $SourcePath -Install:$Install -Update:$Update -WhatIf:$WhatIfPreference
}
Invoke-OpenGuidePlatformBootstrap @args
