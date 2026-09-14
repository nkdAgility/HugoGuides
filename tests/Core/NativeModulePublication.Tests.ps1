BeforeAll {
    function ConvertTo-PackageManifest($Manifest) {
        $copy=@{}+$Manifest
        $copy.schemaVersion=2
        $copy.packages=@{GuideSite=@{archive='OpenGuidePlatform-GuideSite.zip';version=$copy.version;sha256=$copy.sha256}}
        $copy.packages.PlatformBuild=@{archive='OpenGuidePlatform-PlatformBuild.zip';version=$copy.version;sha256=(Get-FileHash "$assets/OpenGuidePlatform-PlatformBuild.zip").Hash.ToLowerInvariant()}
        $copy.Remove('archive');$copy.Remove('sha256');$copy.Remove('bootstrapSha256')
        return $copy
    }

    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $publisher=Join-Path $root 'system/OpenGuidePlatform.PowerShell.PlatformBuild/Release/Publish-PlatformPreviewRelease.ps1'
    function git {
        $global:LASTEXITCODE=0
        if($args -contains 'rev-parse'){return 'a'*40}
        if($args[0] -eq 'ls-remote'){return $global:OgpNativeTagExisting}
        throw 'Unexpected Git operation.'
    }
    function gh {
        $global:LASTEXITCODE=0
        $global:OgpNativeTagCalls.Add(($args -join ' '))
        if($args[0] -eq 'api'){
            if($global:OgpNativeTagFailure){$global:LASTEXITCODE=1}
            return
        }
        if($args[0] -eq 'release' -and $args[1] -eq 'view'){$global:LASTEXITCODE=1;return}
        if($args[0] -eq 'release' -and $args[1] -eq 'create'){return}
        throw 'Unexpected GitHub operation.'
    }
}
Describe 'Coordinated native module publication' {
    BeforeEach {
        $global:OgpNativeTagCalls=[Collections.Generic.List[string]]::new()
        $global:OgpNativeTagExisting=@()
        $global:OgpNativeTagFailure=$false
        $assets=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($assets)|Out-Null
        [IO.File]::WriteAllText("$assets/OpenGuidePlatform-GuideSite.zip",'already validated package bytes')
        [IO.File]::WriteAllText("$assets/OpenGuidePlatform-PlatformBuild.zip",'platform engineering bytes')
        $manifest=@{version='0.1.0-Preview.1';channel='preview';archive='OpenGuidePlatform-GuideSite.zip';sourceCommit=('a'*40);sha256=(Get-FileHash "$assets/OpenGuidePlatform-GuideSite.zip").Hash.ToLowerInvariant();nativeHugoModule=@{path='github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides';version='v0.1.0-Preview.1';tag='system/OpenGuidePlatform.Hugo.Guides/v0.1.0-Preview.1';sourceCommit=('a'*40)}}
        [IO.File]::WriteAllText("$assets/release-manifest.json",(ConvertTo-PackageManifest $manifest|ConvertTo-Json -Depth 10))
        $priorRepo=$env:GITHUB_REPOSITORY
        $env:GITHUB_REPOSITORY='example/platform'
    }
    AfterEach { $env:GITHUB_REPOSITORY=$priorRepo }
    It 'publishes a nested module tag before making its coordinated release available' {
        & $publisher -WorkspaceRoot $root -Repository example/platform -OutputPath $assets
        $global:OgpNativeTagCalls[0] | Should -Match 'refs/tags/system/OpenGuidePlatform.Hugo.Guides/v0.1.0-Preview.1'
        $global:OgpNativeTagCalls[-1] | Should -Match '^release create v0.1.0-Preview.1 '
    }
    It 'publishes workspace-relative assets when invoked from another working directory' {
        $workspace=Split-Path $assets -Parent
        $relativeAssets=Split-Path $assets -Leaf
        Push-Location $root
        try { & $publisher -WorkspaceRoot $workspace -Repository example/platform -OutputPath $relativeAssets }
        finally { Pop-Location }
        Test-Path "$assets/release-notes.md" | Should -BeTrue
        $global:OgpNativeTagCalls[-1] | Should -Match ([regex]::Escape("$assets/OpenGuidePlatform-GuideSite.zip"))
    }
    It 'reuses an existing matching tag without moving or recreating it' {
        $global:OgpNativeTagExisting=@(('a'*40)+"`trefs/tags/system/OpenGuidePlatform.Hugo.Guides/v0.1.0-Preview.1")
        & $publisher -WorkspaceRoot $root -Repository example/platform -OutputPath $assets
        @($global:OgpNativeTagCalls|Where-Object {$_ -match '^api '}).Count | Should -Be 0
    }
    It 'refuses a conflicting immutable module tag' {
        $global:OgpNativeTagExisting=@(('b'*40)+"`trefs/tags/system/OpenGuidePlatform.Hugo.Guides/v0.1.0-Preview.1")
        { & $publisher -WorkspaceRoot $root -Repository example/platform -OutputPath $assets } | Should -Throw '*Existing native Hugo tag differs*'
        $global:OgpNativeTagCalls.Count | Should -Be 0
    }
    It 'does not publish the platform when module publication fails' {
        $global:OgpNativeTagFailure=$true
        { & $publisher -WorkspaceRoot $root -Repository example/platform -OutputPath $assets } | Should -Throw '*Native Hugo tag publication failed*'
        @($global:OgpNativeTagCalls|Where-Object {$_ -match '^release create '}).Count | Should -Be 0
    }
    It 'rejects a module version inconsistent with the tested package' {
        $manifest.nativeHugoModule.version='v9.0.0'
        [IO.File]::WriteAllText("$assets/release-manifest.json",(ConvertTo-PackageManifest $manifest|ConvertTo-Json -Depth 10))
        { & $publisher -WorkspaceRoot $root -Repository example/platform -OutputPath $assets } | Should -Throw '*Native Hugo publication identity differs*'
        $global:OgpNativeTagCalls.Count | Should -Be 0
    }
}
AfterAll { Remove-Variable OgpNativeTagCalls,OgpNativeTagExisting,OgpNativeTagFailure -Scope Global -ErrorAction SilentlyContinue }
