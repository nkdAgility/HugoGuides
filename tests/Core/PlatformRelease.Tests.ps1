BeforeAll {
    function ConvertTo-PackageManifest($Manifest) {
        $copy=@{}+$Manifest
        $copy.schemaVersion=2
        $copy.packages=@{GuideSite=@{archive='OpenGuidePlatform-GuideSite.zip';version=$copy.version;sha256=$copy.sha256}}
        $copy.Remove('archive');$copy.Remove('sha256');$copy.Remove('bootstrapSha256')
        return $copy
    }

    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $installer=Join-Path $root '.build/Restore-OpenGuidePlatform.ps1'
    function gh {
        $global:LASTEXITCODE=0
        if($args[0] -eq 'api'){
            return (ConvertTo-Json -InputObject @(@(@{tag_name='v1.2.3-Preview.4';target_commitish=$global:OgpReleaseTestCommit;draft=$false;prerelease=$false;assets=@(@{name='OpenGuidePlatform-GuideSite.zip'});published_at='2026-09-01T00:00:00Z'})) -Depth 5)
        }
        if($args[0] -eq 'release' -and $args[1] -eq 'view'){
            return (@{tagName='v1.2.3-Preview.4';targetCommitish=$global:OgpReleaseTestCommit;isDraft=$false}|ConvertTo-Json)
        }
        if($args[0] -eq 'release' -and $args[1] -eq 'download'){
            $index=[Array]::IndexOf($args,'--dir')
            Copy-Item "$global:OgpReleaseTestAssets/*" $args[$index+1]
            return
        }
        throw 'Unexpected GitHub invocation in installer test.'
    }
}
Describe 'Released platform restoration boundary' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($workspace)|Out-Null
        $global:OgpReleaseTestAssets=Join-Path $workspace 'assets'
        [IO.Directory]::CreateDirectory($global:OgpReleaseTestAssets)|Out-Null
        $global:OgpReleaseTestCommit='a'*40
        $manifest=@{product='OpenGuidePlatform';version='1.2.3-Preview.4';sourceCommit=('a'*40);archive='OpenGuidePlatform-GuideSite.zip';sha256='invalid'}
        [IO.File]::WriteAllText("$global:OgpReleaseTestAssets/OpenGuidePlatform-GuideSite.zip",'not a zip')
        [IO.File]::WriteAllText("$global:OgpReleaseTestAssets/release-manifest.json",(ConvertTo-PackageManifest $manifest|ConvertTo-Json -Depth 10))
        Push-Location $workspace
    }
    AfterEach { Pop-Location }
    It 'rejects a release from another source commit before installing' {
        $global:OgpReleaseTestCommit='b'*40
        { & $installer -ReleaseTag v1.2.3-Preview.4 -ExpectedCommit ('a'*40) -OutputPath .processing/install } | Should -Throw '*source/tag*'
        Test-Path .processing/install | Should -BeFalse
    }
    It 'discovers the latest installable production release without a caller commit' {
        { & $installer -OutputPath .processing/install } | Should -Throw '*digest mismatch*'
        Test-Path .processing/install | Should -BeFalse
    }
    It 'rejects a corrupt published asset before extraction' {
        { & $installer -ReleaseTag v1.2.3-Preview.4 -ExpectedCommit ('a'*40) -OutputPath .processing/install } | Should -Throw '*digest mismatch*'
        Test-Path .processing/install | Should -BeFalse
    }
    It 'rejects archive traversal even when its checksum matches' {
        Remove-Item "$global:OgpReleaseTestAssets/OpenGuidePlatform-GuideSite.zip"
        $zip=[IO.Compression.ZipFile]::Open("$global:OgpReleaseTestAssets/OpenGuidePlatform-GuideSite.zip",[IO.Compression.ZipArchiveMode]::Create)
        try{$null=$zip.CreateEntry('../escaped.txt')}finally{$zip.Dispose()}
        $manifest.sha256=(Get-FileHash "$global:OgpReleaseTestAssets/OpenGuidePlatform-GuideSite.zip").Hash.ToLowerInvariant()
        [IO.File]::WriteAllText("$global:OgpReleaseTestAssets/release-manifest.json",(ConvertTo-PackageManifest $manifest|ConvertTo-Json -Depth 10))
        { & $installer -ReleaseTag v1.2.3-Preview.4 -ExpectedCommit ('a'*40) -OutputPath .processing/install } | Should -Throw '*Unsafe release archive*'
        Test-Path .processing/escaped.txt | Should -BeFalse
    }
    It 'refuses an existing installation instead of mixing releases' {
        [IO.Directory]::CreateDirectory((Join-Path $workspace '.processing/install'))|Out-Null
        { & $installer -ReleaseTag v1.2.3-Preview.4 -ExpectedCommit ('a'*40) -OutputPath .processing/install } | Should -Throw '*already exists*'
    }
}

AfterAll { Remove-Variable OgpReleaseTestCommit,OgpReleaseTestAssets -Scope Global -ErrorAction SilentlyContinue }
