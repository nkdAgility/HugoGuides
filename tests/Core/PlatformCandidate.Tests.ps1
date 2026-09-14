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
    function Write-CandidateFixture {
        param([string]$Directory,[string]$Commit=('a'*40),[string]$Version='1.2.3-Preview.4',[switch]$Traversal,[switch]$WrongMetadata,[switch]$CorruptInner)
        $assets=Join-Path $Directory 'assets'
        $payload=Join-Path $Directory 'payload'
        [IO.Directory]::CreateDirectory($assets)|Out-Null
        [IO.Directory]::CreateDirectory($payload)|Out-Null
        [IO.Directory]::CreateDirectory("$payload/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption")|Out-Null
        Copy-Item "$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Confirm-PlatformPackage.ps1" "$payload/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/"
        @{product='OpenGuidePlatform';version=$Version;sourceCommit=if($WrongMetadata){'b'*40}else{$Commit}}|ConvertTo-Json|Set-Content "$payload/platform.json"
        if($Traversal){
            $zip=[IO.Compression.ZipFile]::Open("$assets/OpenGuidePlatform-GuideSite.zip",[IO.Compression.ZipArchiveMode]::Create)
            try{$null=$zip.CreateEntry('../escaped.txt')}finally{$zip.Dispose()}
        }else{[IO.Compression.ZipFile]::CreateFromDirectory($payload,"$assets/OpenGuidePlatform-GuideSite.zip")}
        ConvertTo-PackageManifest @{product='OpenGuidePlatform';version=$Version;sourceCommit=$Commit;archive='OpenGuidePlatform-GuideSite.zip';sha256=if($CorruptInner){'0'*64}else{(Get-FileHash "$assets/OpenGuidePlatform-GuideSite.zip").Hash.ToLowerInvariant()};}|ConvertTo-Json -Depth 10|Set-Content "$assets/release-manifest.json"
        $bundle=Join-Path $Directory 'candidate.zip'
        [IO.Compression.ZipFile]::CreateFromDirectory($assets,$bundle)
        return $bundle
    }
}
Describe 'Candidate ZIP restoration before publication' {
    BeforeEach {
        $workflowEnvironment=@{}
        foreach($name in @('PLATFORM_RELEASE','PLATFORM_PACKAGE_URL','PLATFORM_PACKAGE_SHA256','PLATFORM_VERSION')){
            $workflowEnvironment[$name]=[Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name,$null)
        }
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($workspace)|Out-Null
        Push-Location $workspace
        Mock Import-Module {}
        Mock Invoke-WebRequest { Copy-Item -LiteralPath $global:OgpCandidateFixtureZip -Destination $OutFile }
        $global:OgpCandidateFixtureZip=$null
        $arguments=@{PackageUrl='https://api.github.com/repos/example/platform/actions/artifacts/123/zip';ExpectedVersion='1.2.3-Preview.4';ExpectedCommit=('a'*40);OutputPath='.processing/install'}
    }
    AfterEach {
        Pop-Location
        foreach($name in $workflowEnvironment.Keys){[Environment]::SetEnvironmentVariable($name,$workflowEnvironment[$name])}
    }
    It 'selects the verified candidate from workflow inputs without YAML branching' {
        $global:OgpCandidateFixtureZip=Write-CandidateFixture $workspace
        $env:PLATFORM_PACKAGE_URL=$arguments.PackageUrl
        $env:PLATFORM_PACKAGE_SHA256=(Get-FileHash $global:OgpCandidateFixtureZip).Hash
        $env:PLATFORM_VERSION=$arguments.ExpectedVersion
        & $installer -FromWorkflow -ExpectedCommit $arguments.ExpectedCommit -OutputPath $arguments.OutputPath
        (Get-Content .processing/install/platform.json -Raw|ConvertFrom-Json).version|Should -Be $arguments.ExpectedVersion
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
    }
    It 'rejects conflicting workflow package selection before network access' {
        $env:PLATFORM_PACKAGE_URL=$arguments.PackageUrl
        $env:PLATFORM_RELEASE='v1.2.3'
        { & $installer -FromWorkflow -ExpectedCommit $arguments.ExpectedCommit -OutputPath $arguments.OutputPath }|Should -Throw '*not both*'
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }
    It 'rejects candidate identity without a workflow package URL' {
        $env:PLATFORM_VERSION='1.2.3'
        { & $installer -FromWorkflow -ExpectedCommit $arguments.ExpectedCommit -OutputPath $arguments.OutputPath }|Should -Throw '*requires a package URL*'
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }
    It 'restores the verified build ZIP without querying any release' {
        $global:OgpCandidateFixtureZip=Write-CandidateFixture $workspace
        $arguments.PackageSha256=(Get-FileHash $global:OgpCandidateFixtureZip).Hash
        & $installer @arguments
        (Get-Content .processing/install/platform.json -Raw|ConvertFrom-Json).sourceCommit | Should -Be ('a'*40)
        Should -Invoke Import-Module -Times 2 -Exactly
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
    }
    It 'rejects an altered transport ZIP before extracting candidate files' {
        $global:OgpCandidateFixtureZip=Write-CandidateFixture $workspace
        $arguments.PackageSha256='0'*64
        { & $installer @arguments } | Should -Throw '*Candidate package digest mismatch*'
        Test-Path .processing/install | Should -BeFalse
        Should -Invoke Import-Module -Times 0 -Exactly
    }
    It 'rejects an inner package whose digest disagrees with its manifest' {
        $global:OgpCandidateFixtureZip=Write-CandidateFixture $workspace -CorruptInner
        $arguments.PackageSha256=(Get-FileHash $global:OgpCandidateFixtureZip).Hash
        { & $installer @arguments } | Should -Throw '*Release package digest mismatch*'
        Test-Path .processing/install | Should -BeFalse
        Should -Invoke Import-Module -Times 0 -Exactly
    }
    It 'rejects a different source commit or version before executing candidate code' -ForEach @(@{Field='ExpectedCommit';Value=('b'*40)},@{Field='ExpectedVersion';Value='9.9.9-Preview.1'}) {
        $global:OgpCandidateFixtureZip=Write-CandidateFixture $workspace
        $arguments.PackageSha256=(Get-FileHash $global:OgpCandidateFixtureZip).Hash
        $arguments[$Field]=$Value
        { & $installer @arguments } | Should -Throw '*manifest does not match*'
        Test-Path .processing/install | Should -BeFalse
        Should -Invoke Import-Module -Times 0 -Exactly
    }
    It 'rejects unsafe inner paths even when both checksums match' {
        $global:OgpCandidateFixtureZip=Write-CandidateFixture $workspace -Traversal
        $arguments.PackageSha256=(Get-FileHash $global:OgpCandidateFixtureZip).Hash
        { & $installer @arguments } | Should -Throw '*Unsafe release archive*'
        Test-Path .processing/escaped.txt | Should -BeFalse
        Should -Invoke Import-Module -Times 0 -Exactly
    }
    It 'rejects installed metadata differing from the verified manifest' {
        $global:OgpCandidateFixtureZip=Write-CandidateFixture $workspace -WrongMetadata
        $arguments.PackageSha256=(Get-FileHash $global:OgpCandidateFixtureZip).Hash
        { & $installer @arguments } | Should -Throw '*Installed platform identity mismatch*'
        Should -Invoke Import-Module -Times 0 -Exactly
    }
    It 'refuses insecure URLs before downloading a candidate' {
        $arguments.PackageUrl='http://example.invalid/candidate.zip'
        $arguments.PackageSha256='0'*64
        { & $installer @arguments } | Should -Throw '*HTTPS*'
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }
}
Describe 'Platform publication dependency' {
    It 'allows publication only for pushes to main, never PR or manual runs' {
        Import-Module powershell-yaml -MinimumVersion 0.4.12
        $main=Get-Content "$root/.github/workflows/main.yaml" -Raw|ConvertFrom-Yaml
        # An exact allowlist prevents same-repository PR exceptions and bypass conditions.
        $main.jobs.release['if'] | Should -Be '${{ github.event_name == ''push'' && github.ref == ''refs/heads/main'' }}'
    }
    It 'requires the direct sample consumer to succeed before publishing the same build artifact' {
        Import-Module powershell-yaml -MinimumVersion 0.4.12
        $main=Get-Content "$root/.github/workflows/main.yaml" -Raw|ConvertFrom-Yaml
        $shared=Get-Content "$root/.github/workflows/guide-site-build.yaml" -Raw|ConvertFrom-Yaml
        $main.jobs.sample.uses | Should -Be './.github/workflows/guide-site-build.yaml'
        $main.jobs.sample.needs | Should -Be build
        $main.jobs.release.needs | Should -Contain sample
        $main.jobs.release.needs | Should -Contain build
        $main.jobs.release['if'] | Should -Not -Match 'always\(|failure\(|cancelled\('
        $main.jobs.sample.with['platform-package-url'] | Should -Match 'needs.build.outputs.package-url'
        $main.jobs.sample.with['platform-package-sha256'] | Should -Match 'needs.build.outputs.package-sha256'
        $download=@($main.jobs.release.steps|Where-Object { $_.Contains('uses') -and $_['uses'] -like 'actions/download-artifact@*' })[0]
        $download.with['artifact-ids'] | Should -Match 'needs.build.outputs.artifact-id'
        $shared.jobs.build.needs | Should -Be prepare
        $shared.jobs.validate.needs | Should -Be build
        $shared.jobs.deploy.needs | Should -Be validate
        $shared.jobs.verify.needs | Should -Be deploy
        Test-Path "$root/.github/workflows/sample-main.yaml" | Should -BeFalse
    }
}
AfterAll { Remove-Variable OgpCandidateFixtureZip -Scope Global -ErrorAction SilentlyContinue }
