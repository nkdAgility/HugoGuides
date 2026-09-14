BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1') -Force
}
Describe 'Module freshness evidence' {
    It 'reports a current pin as informational' {
        Mock Invoke-GuideGoModuleQuery -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { [pscustomobject]@{Version='v0.8.4'} }
        (Get-GuideModuleFreshness $TestDrive).Code | Should -Be MODULE_CURRENT
    }
    It 'warns about a different latest version without requesting an update' {
        Mock Invoke-GuideGoModuleQuery -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild {
            param($SourcePath,$Query)
            [pscustomobject]@{Version=if($Query.EndsWith('@latest')){'v0.9.0'}else{'v0.8.4'}}
        }
        $result=Get-GuideModuleFreshness $TestDrive
        $result.Code | Should -Be MODULE_VERSION_DIFFERS
        $result.Severity | Should -Be warning
        $result.Installed | Should -Be v0.8.4
        $result.Latest | Should -Be v0.9.0
    }
    It 'does not claim freshness when the registry is unavailable or a replacement is active' {
        Mock Invoke-GuideGoModuleQuery -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { throw 'Registry unavailable' }
        (Get-GuideModuleFreshness $TestDrive).Code | Should -Be MODULE_FRESHNESS_UNAVAILABLE
        Mock Invoke-GuideGoModuleQuery -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { [pscustomobject]@{Version='v0.8.4';Replace=@{Path='../local'}} }
        (Get-GuideModuleFreshness $TestDrive).Code | Should -Be MODULE_REPLACEMENT_ACTIVE
    }
}