BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $resolver="$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1"
}
Describe 'Consumer and platform package separation' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $assets=Join-Path $workspace 'assets'
        $guide=Join-Path $workspace 'guide'
        $engineering=Join-Path $workspace 'engineering'
        [IO.Directory]::CreateDirectory($assets)|Out-Null
        [IO.Directory]::CreateDirectory("$guide/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption")|Out-Null
        [IO.Directory]::CreateDirectory("$guide/system/OpenGuidePlatform.PowerShell.GuideSiteBuild")|Out-Null
        [IO.Directory]::CreateDirectory("$engineering/system/OpenGuidePlatform.PowerShell.PlatformBuild")|Out-Null
        Copy-Item "$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Confirm-PlatformPackage.ps1" "$guide/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/"
        Set-Content "$guide/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" '# fixture'
        Set-Content "$engineering/system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1" '# fixture'
        $identity=@{product='OpenGuidePlatform';version='1.0.0-Preview.1';sourceCommit=('a'*40)}
        $identity|ConvertTo-Json|Set-Content "$guide/platform.json"
        [IO.Compression.ZipFile]::CreateFromDirectory($guide,"$assets/OpenGuidePlatform-GuideSite.zip")
        $dependency=@{version=$identity.version;sha256=(Get-FileHash "$assets/OpenGuidePlatform-GuideSite.zip").Hash.ToLowerInvariant()}
        $platformIdentity=@{}+$identity
        $platformIdentity.package='PlatformBuild';$platformIdentity.dependencies=@{GuideSite=$dependency}
        $platformIdentity|ConvertTo-Json -Depth 10|Set-Content "$engineering/platform-build.json"
        [IO.Compression.ZipFile]::CreateFromDirectory($engineering,"$assets/OpenGuidePlatform-PlatformBuild.zip")
        $manifest=@{}+$identity
        $manifest.schemaVersion=2
        $manifest.packages=@{
            GuideSite=@{archive='OpenGuidePlatform-GuideSite.zip';version=$identity.version;sha256=$dependency.sha256}
            PlatformBuild=@{archive='OpenGuidePlatform-PlatformBuild.zip';version=$identity.version;sha256=(Get-FileHash "$assets/OpenGuidePlatform-PlatformBuild.zip").Hash.ToLowerInvariant();dependencies=@{GuideSite=@{}+$dependency}}
        }
        $manifest|ConvertTo-Json -Depth 10|Set-Content "$assets/release-manifest.json"
        Mock Invoke-WebRequest {throw 'Explicit packages must restore offline.'}
    }
    It 'restores only consumer tooling for a guide-site build' {
        [IO.File]::Delete("$assets/OpenGuidePlatform-PlatformBuild.zip")
        $selected=& $resolver -WorkspaceRoot $workspace -PlatformPath "$assets/OpenGuidePlatform-GuideSite.zip"
        Test-Path "$selected/system/OpenGuidePlatform.PowerShell.GuideSiteBuild"|Should -BeTrue
        Test-Path "$selected/system/OpenGuidePlatform.PowerShell.PlatformBuild"|Should -BeFalse
    }
    It 'restores both matching packages for platform engineering' {
        $selected=& $resolver -WorkspaceRoot $workspace -PlatformPath "$assets/OpenGuidePlatform-GuideSite.zip" -Product Platform
        Test-Path "$selected/system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1"|Should -BeTrue
        # A restored directory is also a valid explicit source and needs no re-download.
        & $resolver -WorkspaceRoot $workspace -PlatformPath $selected -Product Platform|Should -Be $selected
    }
    It 'rejects a dependency from a different build before restoring platform engineering' {
        $manifest.packages.PlatformBuild.dependencies.GuideSite.sha256='0'*64
        $manifest|ConvertTo-Json -Depth 10|Set-Content "$assets/release-manifest.json"
        { & $resolver -WorkspaceRoot $workspace -PlatformPath "$assets/OpenGuidePlatform-GuideSite.zip" -Product Platform }|Should -Throw '*same release*'
    }
    It 'rejects corrupted platform engineering bytes' {
        [IO.File]::AppendAllText("$assets/OpenGuidePlatform-PlatformBuild.zip",'corrupt')
        { & $resolver -WorkspaceRoot $workspace -PlatformPath "$assets/OpenGuidePlatform-GuideSite.zip" -Product Platform }|Should -Throw '*digest mismatch*'
    }
    It 'cleans validation extraction after a package identity failure without deleting input assets' {
        $checker="$root/system/OpenGuidePlatform.PowerShell.PlatformBuild/Packaging/Test-OpenGuidePlatformPackage.ps1"
        { & $checker -WorkspaceRoot $workspace -OutputPath 'assets' } | Should -Throw
        @(Get-ChildItem "$workspace/.processing/package-validation" -Directory).Count | Should -Be 0
        Test-Path "$assets/OpenGuidePlatform-GuideSite.zip" | Should -BeTrue
    }
    It 'cleans partial restoration when the second package is corrupt' {
        [IO.File]::AppendAllText("$assets/OpenGuidePlatform-PlatformBuild.zip",'corrupt')
        $checker="$root/system/OpenGuidePlatform.PowerShell.PlatformBuild/Packaging/Test-OpenGuidePlatformPackage.ps1"
        { & $checker -WorkspaceRoot $workspace -OutputPath 'assets' } | Should -Throw '*digest mismatch*'
        @(Get-ChildItem "$workspace/.processing/package-validation" -Directory).Count | Should -Be 0
        Test-Path "$assets/OpenGuidePlatform-GuideSite.zip" | Should -BeTrue
    }

}
