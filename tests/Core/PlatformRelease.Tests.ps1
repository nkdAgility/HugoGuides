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
        $global:OgpReleaseTestCalls.Add(($args -join ' '))
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
        $global:OgpReleaseTestCalls=[Collections.Generic.List[string]]::new()
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
    It 'fails with an actionable install instruction instead of silently selecting latest' {
        { & $installer -OutputPath .processing/install } | Should -Throw '*No OGP installation pin*'
        $global:OgpReleaseTestCalls.Count | Should -Be 0
        Test-Path .processing/install | Should -BeFalse
    }
    It 'honors the installed preview pin even with production ring input and does not query latest' {
        New-Item .OpenGuidePlatform -ItemType Directory|Out-Null
        @{schemaVersion=1;releaseTag='v1.2.3-Preview.4';release=@{version='1.2.3-Preview.4';sourceCommit=('a'*40)}}|ConvertTo-Json|Set-Content .OpenGuidePlatform/installation.json
        $before=Get-FileHash .OpenGuidePlatform/installation.json
        { & $installer -PlatformRing production -OutputPath .processing/install } | Should -Throw '*digest mismatch*'
        $global:OgpReleaseTestCalls[0] | Should -Match '^release view v1.2.3-Preview.4 '
        @($global:OgpReleaseTestCalls|Where-Object {$_ -match '^api '}).Count|Should -Be 0
        (Get-FileHash .OpenGuidePlatform/installation.json).Hash|Should -Be $before.Hash
    }
    It 'uses the same installed pin from a workflow without changing the site target' {
        New-Item .OpenGuidePlatform -ItemType Directory|Out-Null
        @{schemaVersion=1;releaseTag='v1.2.3-Preview.4';release=@{version='1.2.3-Preview.4';sourceCommit=('a'*40)}}|ConvertTo-Json|Set-Content .OpenGuidePlatform/installation.json
        $saved=@{};foreach($name in @('PLATFORM_RING','PLATFORM_RELEASE','PLATFORM_PACKAGE_URL','PLATFORM_PACKAGE_SHA256','PLATFORM_VERSION','SITE_TARGET')){$saved[$name]=[Environment]::GetEnvironmentVariable($name);[Environment]::SetEnvironmentVariable($name,$null)}
        try{
            $env:PLATFORM_RING='production';$env:SITE_TARGET='production'
            { & $installer -FromWorkflow -OutputPath .processing/install } | Should -Throw '*digest mismatch*'
            $global:OgpReleaseTestCalls[0] | Should -Match '^release view v1.2.3-Preview.4 '
            $env:SITE_TARGET|Should -Be production
            @($global:OgpReleaseTestCalls|Where-Object {$_ -match '^api '}).Count|Should -Be 0
        }finally{foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name])}}
    }
    It 'rejects a malformed installation pin before contacting releases' {
        New-Item .OpenGuidePlatform -ItemType Directory|Out-Null
        @{schemaVersion=1;releaseTag='v1.2.3-Preview.5';release=@{version='1.2.3-Preview.4';sourceCommit=('a'*40)}}|ConvertTo-Json|Set-Content .OpenGuidePlatform/installation.json
        { & $installer -OutputPath .processing/install } | Should -Throw '*installation pin is invalid*'
        $global:OgpReleaseTestCalls.Count|Should -Be 0
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

AfterAll { Remove-Variable OgpReleaseTestCalls,OgpReleaseTestCommit,OgpReleaseTestAssets -Scope Global -ErrorAction SilentlyContinue }
