BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
}
Describe 'Hugo toolchain prerequisites' {
    It 'accepts supported Extended and Extended deployment variants' {
        Mock Invoke-GuideHugoVersion -ModuleName OpenGuidePlatform.PowerShell.Build { 'hugo v0.146.0+extended windows/amd64 BuildDate=2025-01-01' }
        (Get-GuideHugoToolchain).Version | Should -Be '0.146.0'
        Mock Invoke-GuideHugoVersion -ModuleName OpenGuidePlatform.PowerShell.Build { 'hugo v0.164.0-abcdef+extended+withdeploy linux/amd64 BuildDate=2026-01-01' }
        (Get-GuideHugoToolchain).Extended | Should -BeTrue
    }
    It 'rejects a standard binary even at a newer version' {
        Mock Invoke-GuideHugoVersion -ModuleName OpenGuidePlatform.PowerShell.Build { 'hugo v0.164.0 linux/amd64 BuildDate=2026-01-01' }
        {Get-GuideHugoToolchain} | Should -Throw '*not an Extended build*'
    }
    It 'rejects an old Extended binary before rendering' {
        Mock Invoke-GuideHugoVersion -ModuleName OpenGuidePlatform.PowerShell.Build { 'hugo v0.145.0+extended windows/amd64 BuildDate=2025-01-01' }
        {Get-GuideHugoToolchain} | Should -Throw '*below required minimum*'
    }
    It 'does not claim valid tools when execution or parsing fails' {
        Mock Invoke-GuideHugoVersion -ModuleName OpenGuidePlatform.PowerShell.Build { 'unrecognized development build' }
        {Get-GuideHugoToolchain} | Should -Throw '*Cannot establish*'
        Mock Invoke-GuideHugoVersion -ModuleName OpenGuidePlatform.PowerShell.Build { throw 'Executable unavailable' }
        {Get-GuideHugoToolchain} | Should -Throw '*Executable unavailable*'
    }
}