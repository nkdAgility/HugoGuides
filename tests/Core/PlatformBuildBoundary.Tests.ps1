BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $resolver="$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1"
}
Describe 'Platform and consumer module boundary' {
    It 'imports the consumer module without the platform engineering module' {
        $scriptPath=Join-Path $TestDrive 'consumer.ps1'
        @"
Import-Module '$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1'
if(Get-Module OpenGuidePlatform.PowerShell.PlatformBuild){throw 'Consumer loaded platform engineering.'}
if(-not (Get-Command Invoke-GuideSiteBuild)){throw 'Consumer stages unavailable.'}
"@|Set-Content $scriptPath
        & (Join-Path $PSHOME $(if($IsWindows){'pwsh.exe'}else{'pwsh'})) -NoProfile -File $scriptPath
        $LASTEXITCODE|Should -Be 0
    }
    It 'selects the supplied checkout without consulting an installation' {
        & $resolver -WorkspaceRoot $TestDrive -PlatformSource Local -PlatformPath $root|Should -Be $root
        & $resolver -WorkspaceRoot $TestDrive -DefaultPlatformRoot $root|Should -Be $root
    }
    It 'rejects conflicting sources instead of falling back' {
        {& $resolver -WorkspaceRoot $TestDrive -PlatformSource Preview -PlatformPath $root}|Should -Throw '*not both*'
        {& $resolver -WorkspaceRoot $TestDrive -PlatformSource Local -PlatformRelease v1.0.0}|Should -Throw '*cannot also*'
        {& $resolver -WorkspaceRoot $TestDrive -PlatformSource Local}|Should -Throw '*Supply -PlatformPath*'
    }
}
