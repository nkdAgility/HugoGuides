BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $validator="$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Confirm-PlatformPackage.ps1"
}
Describe 'Shared installed package identity' {
    BeforeEach {
        $package=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($package)|Out-Null
        $manifest=@{product='OpenGuidePlatform';version='1.2.3-Preview.1';sourceCommit=('a'*40);workflow=@{version='v1.2.3-Preview.1'}}
        [IO.File]::WriteAllText("$package/platform.json",($manifest|ConvertTo-Json -Depth 10))
    }
    It 'accepts matching package and release identities' {
        (& $validator -PackageRoot $package -Manifest $manifest).version | Should -Be $manifest.version
    }
    It 'rejects metadata drift inside a checksum-verified package' {
        $manifest.workflow.version='v9.0.0'
        {& $validator -PackageRoot $package -Manifest $manifest} | Should -Throw '*coordinated identity differs: workflow*'
    }
}
