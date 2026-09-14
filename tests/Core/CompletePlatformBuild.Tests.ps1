BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1" -Force
}
Describe 'Complete platform execution decisions' {
    BeforeEach {
        $global:OgpPlatformOperations=[Collections.Generic.List[string]]::new()
        Mock Get-PlatformBuildVersion -ModuleName OpenGuidePlatform.PowerShell.PlatformBuild { [pscustomobject]@{SemVer='1.0.0-preview';Sha=('a'*40)} }
        Mock Get-GuideHugoToolchain -ModuleName OpenGuidePlatform.PowerShell.PlatformBuild {}
        Mock Import-Module -ModuleName OpenGuidePlatform.PowerShell.PlatformBuild {}
        Mock Invoke-PlatformBuildOperation -ModuleName OpenGuidePlatform.PowerShell.PlatformBuild { $global:OgpPlatformOperations.Add($Operation) }
        Mock Test-PlatformCandidateSample -ModuleName OpenGuidePlatform.PowerShell.PlatformBuild { $global:OgpPlatformOperations.Add('Sample'); if($global:OgpSampleFails){throw 'Sample rejected'} }
        $global:OgpSampleFails=$false
    }
    It 'runs package acceptance and sample before any explicit publication' {
        Invoke-PlatformBuild -WorkspaceRoot $TestDrive -OutputPath .processing/run
        $global:OgpPlatformOperations[-2]|Should -Be 'Test-OpenGuidePlatformPackage'
        $global:OgpPlatformOperations[-1]|Should -Be 'Sample'
        $global:OgpPlatformOperations|Should -Not -Contain 'Publish-PlatformRelease'
    }
    It 'requires explicit sample deployment for complete-run publication' {
        {Invoke-PlatformBuild -WorkspaceRoot $TestDrive -Publish}|Should -Throw '*sample deployment and live verification*'
        Should -Invoke Invoke-PlatformBuildOperation -ModuleName OpenGuidePlatform.PowerShell.PlatformBuild -Times 0 -Exactly
    }
    It 'does not publish when sample acceptance fails' {
        $global:OgpSampleFails=$true
        {Invoke-PlatformBuild -WorkspaceRoot $TestDrive -OutputPath .processing/run -Publish -DeploySample -DeploymentEnvironment preview}|Should -Throw '*Sample rejected*'
        $global:OgpPlatformOperations|Should -Not -Contain 'Publish-PlatformRelease'
    }
}
AfterAll {Remove-Variable OgpPlatformOperations,OgpSampleFails -Scope Global -ErrorAction SilentlyContinue}
