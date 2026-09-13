BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $bootstrap=Join-Path $root 'bootstrap.ps1'
    function gh {
        $global:LASTEXITCODE=0
        if($global:OgpBootstrapOffline){throw 'Unexpected network access.'}
        if($args[0] -eq 'api'){
            return (@(@{draft=$false;prerelease=$true;tag_name='v1.2.3-Preview.2';published_at='2026-09-13';assets=@(@{name='bootstrap.ps1'})})|ConvertTo-Json -Depth 5)
        }
        if($args[1] -eq 'view'){
            return (@{tagName=$args[2];targetCommitish=('a'*40);isDraft=$false;isPrerelease=$true}|ConvertTo-Json)
        }
        if($args[1] -eq 'download'){
            $directory=$args[[Array]::IndexOf($args,'--dir')+1]
            $pattern=$args[[Array]::IndexOf($args,'--pattern')+1]
            [IO.File]::Copy((Join-Path $global:OgpBootstrapAssets[$args[2]] $pattern),(Join-Path $directory $pattern))
            return
        }
        throw 'Unexpected GitHub invocation.'
    }
    $global:OgpBootstrapAssets=@{}
    foreach($version in @('1.2.3-Preview.1','1.2.3-Preview.2')){
        $assets=Join-Path $TestDrive $version
        $stage=Join-Path $assets 'package'
        [IO.Directory]::CreateDirectory("$stage/system")|Out-Null
        foreach($name in @('OpenGuidePlatform.GuideSite.Adoption','OpenGuidePlatform.AgentSkills','OpenGuidePlatform.PowerShell.Core')){
            Copy-Item "$root/system/$name" "$stage/system/" -Recurse
        }
        Copy-Item $bootstrap "$assets/bootstrap.ps1"
        [IO.File]::WriteAllText("$stage/build.ps1",'param($Product,$WorkspaceRoot,$PolicyPath,$Version,$Target,$Stage,$OutputPath) "$Product|$Version|$Target|$PolicyPath"')
        [IO.File]::WriteAllText("$stage/platform.json",(@{version=$version;sourceCommit=('a'*40)}|ConvertTo-Json))
        [IO.Compression.ZipFile]::CreateFromDirectory($stage,"$assets/OpenGuidePlatform.zip")
        $manifest=@{schemaVersion=1;product='OpenGuidePlatform';version=$version;sourceCommit=('a'*40);channel='preview';archive='OpenGuidePlatform.zip';bootstrapSha256=(Get-FileHash "$assets/bootstrap.ps1").Hash.ToLowerInvariant();sha256=(Get-FileHash "$assets/OpenGuidePlatform.zip").Hash.ToLowerInvariant()}
        [IO.File]::WriteAllText("$assets/release-manifest.json",($manifest|ConvertTo-Json))
        $global:OgpBootstrapAssets["v$version"]=$assets
    }
}
Describe 'Guide-site installation and update' {
    BeforeEach {
        $global:OgpBootstrapOffline=$false
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($workspace)|Out-Null
        & git init -q -b codex/adoption $workspace
        Copy-Item "$root/tests/Contracts/fixtures/single-guide.site-policy.json" "$workspace/guide-site.policy.json"
        $parameters=@{WorkspaceRoot=$workspace;ReleaseTag='v1.2.3-Preview.1'}
    }
    It 'installs matching workflow and identical root agent shims without touching policy' {
        $before=(Get-FileHash "$workspace/guide-site.policy.json").Hash
        & $bootstrap -Install @parameters
        $record=Get-Content "$workspace/open-guide-platform.installation.json" -Raw|ConvertFrom-Json
        $record.releaseTag | Should -Be 'v1.2.3-Preview.1'
        Get-Content "$workspace/.github/workflows/main.yaml" -Raw | Should -Match '@v1.2.3-Preview.1'
        (Get-FileHash "$workspace/AGENTS.md").Hash | Should -Be (Get-FileHash "$workspace/CLAUDE.md").Hash
        (Get-FileHash "$workspace/guide-site.policy.json").Hash | Should -Be $before
    }
    It 'updates all managed identities to a selected release' {
        & $bootstrap -Install @parameters
        & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2
        (Get-Content "$workspace/open-guide-platform.installation.json" -Raw|ConvertFrom-Json).releaseTag | Should -Be 'v1.2.3-Preview.2'
        Get-Content "$workspace/.github/workflows/main.yaml" -Raw | Should -Match '@v1.2.3-Preview.2'
    }
    It 'restores offline from the locked cache and runs the installed GuideSite entry point' {
        & $bootstrap -Install @parameters
        $global:OgpBootstrapOffline=$true
        & "$workspace/build.ps1" -Target preview | Should -Be 'GuideSite|1.2.3-Preview.1|preview|guide-site.policy.json'
    }
    It 'rejects modified managed files before changing any tracked file' {
        & $bootstrap -Install @parameters
        $before=[IO.File]::ReadAllText("$workspace/open-guide-platform.installation.json")
        [IO.File]::AppendAllText("$workspace/build.ps1",'# consumer edit')
        { & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2 } | Should -Throw '*Managed-file conflicts*'
        [IO.File]::ReadAllText("$workspace/open-guide-platform.installation.json") | Should -Be $before
    }
    It 'refuses existing consumer instructions without partial installation' {
        [IO.File]::WriteAllText("$workspace/AGENTS.md",'Consumer instructions')
        { & $bootstrap -Install @parameters } | Should -Throw '*Managed-file conflicts*'
        Test-Path "$workspace/build.ps1" | Should -BeFalse
        [IO.File]::ReadAllText("$workspace/AGENTS.md") | Should -Be 'Consumer instructions'
    }
    It 'previews installation without writing managed files' {
        & $bootstrap -Install @parameters -WhatIf
        Test-Path "$workspace/build.ps1" | Should -BeFalse
        Test-Path "$workspace/open-guide-platform.installation.json" | Should -BeFalse
    }
    It 'rejects a corrupt cached archive instead of executing cached code' {
        & $bootstrap -Install @parameters
        $record=Get-Content "$workspace/open-guide-platform.installation.json" -Raw|ConvertFrom-Json
        [IO.File]::AppendAllText("$workspace/.processing/platform-cache/$($record.release.sha256)/OpenGuidePlatform.zip",'corrupt')
        { & $bootstrap -Restore -WorkspaceRoot $workspace } | Should -Throw '*Cached package digest mismatch*'
    }
    It 'selects an installable preview when no release tag is supplied' {
        & $bootstrap -Install -WorkspaceRoot $workspace
        (Get-Content "$workspace/open-guide-platform.installation.json" -Raw|ConvertFrom-Json).releaseTag | Should -Be 'v1.2.3-Preview.2'
    }
    It 'rejects stable adoption and unsafe policy paths before network access' {
        $global:OgpBootstrapOffline=$true
        { & $bootstrap -Install @parameters -Channel stable } | Should -Throw '*Stable adoption is not available*'
        { & $bootstrap -Install @parameters -PolicyPath '../outside.json' } | Should -Throw '*Unsafe installation path*'
    }
    It 'requires a review branch' {
        & git -C $workspace symbolic-ref HEAD refs/heads/main
        { & $bootstrap -Install @parameters } | Should -Throw '*review branch*'
    }
}
AfterAll { Remove-Variable OgpBootstrapAssets,OgpBootstrapOffline -Scope Global -ErrorAction SilentlyContinue }
