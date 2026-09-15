BeforeAll {
    function ConvertTo-PackageManifest($Manifest) {
        $copy=@{}+$Manifest
        $copy.schemaVersion=2
        $copy.packages=@{GuideSite=@{archive='OpenGuidePlatform-GuideSite.zip';version=$copy.version;sha256=$copy.sha256}}
        $copy.Remove('archive');$copy.Remove('sha256');$copy.Remove('bootstrapSha256')
        return $copy
    }

    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $bootstrap=Join-Path $root 'bootstrap.ps1'
    $resolver=Join-Path $root 'system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1'
    $global:OgpRealGh=(Get-Command gh -CommandType Application).Source
    function global:gh {
        $global:LASTEXITCODE=0
        if($args[0] -eq 'actions-lock'){
            if($global:OgpUseRealLock){ & $global:OgpRealGh @args; return }
            if($args -contains '--verify-local'){
                return (@{cli_version='v0.1.6';valid=(-not $global:OgpVerificationFailure)}|ConvertTo-Json)
            }
            $args | Should -Contain '--no-narrow'
            $args | Should -Contain '--no-migrate-local-actions'
            if($global:OgpNoLockFile){return}
            $lock=[ordered]@{workflows=[ordered]@{}}
            [IO.File]::WriteAllText((Join-Path $PWD '.github/workflows/actions.lock'),($lock|ConvertTo-Yaml))
            if($global:OgpLockFailure){$global:LASTEXITCODE=1}
            return
        }
        if($args -contains '--slurp' -and $args -contains '--jq'){throw 'GitHub CLI forbids combining --slurp and --jq.'}
        if($global:OgpBootstrapOffline){throw 'Unexpected network access.'}
        if($args[0] -eq 'api'){
            return (@(@{draft=$false;prerelease=$true;tag_name='v1.2.3-Preview.2';published_at='2026-09-13';assets=@(@{name='OpenGuidePlatform-GuideSite.zip'})},@{draft=$false;prerelease=$false;tag_name='v1.2.3';published_at='2026-09-14';assets=@(@{name='OpenGuidePlatform-GuideSite.zip'})})|ConvertTo-Json -Depth 5)
        }
        if($args[1] -eq 'view'){
            return (@{tagName=$args[2];targetCommitish=('a'*40);isDraft=$false;isPrerelease=$args[2].Contains('-')}|ConvertTo-Json)
        }
        if($args[1] -eq 'download'){
            $directory=$args[[Array]::IndexOf($args,'--dir')+1]
            for($index=0;$index -lt $args.Count;$index++){
                if($args[$index] -eq '--pattern'){
                    $pattern=$args[$index+1]
                    [IO.File]::Copy((Join-Path $global:OgpBootstrapAssets[$args[2]] $pattern),(Join-Path $directory $pattern))
                }
            }
            return
        }
        throw 'Unexpected GitHub invocation.'
    }
    $global:OgpBootstrapAssets=@{}
    foreach($version in @('1.2.3-Preview.1','1.2.3-Preview.2','1.2.3')){
        $assets=Join-Path $TestDrive $version
        $stage=Join-Path $assets 'package'
        [IO.Directory]::CreateDirectory("$stage/system")|Out-Null
        foreach($name in @('OpenGuidePlatform.PowerShell.GuideSiteAdoption','OpenGuidePlatform.Agents.Integration','OpenGuidePlatform.PowerShell.Core')){
            Copy-Item "$root/system/$name" "$stage/system/" -Recurse
        }
        [IO.File]::WriteAllText("$stage/build.ps1",'param($Product,$WorkspaceRoot,$SourcePath,$Version,$Target,$Stage,$OutputPath) "$Product|$Version|$Target|$SourcePath"')
        [IO.Directory]::CreateDirectory("$stage/system/OpenGuidePlatform.PowerShell.GuideSiteBuild")|Out-Null
        [IO.File]::WriteAllText("$stage/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1",'function Invoke-GuideSiteBuild { param($WorkspaceRoot,$SourcePath,$Version,$Target,$Stage,$OutputPath) $Version=(Get-Content "$PSScriptRoot/../../platform.json" -Raw|ConvertFrom-Json).version; "GuideSite|$Version|$Target|$SourcePath" }; Export-ModuleMember -Function Invoke-GuideSiteBuild')
        [IO.File]::WriteAllText("$stage/platform.json",(@{product='OpenGuidePlatform';version=$version;sourceCommit=('a'*40);nativeHugoModule=@{path='github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides';version="v$version";sourceCommit=('a'*40)}}|ConvertTo-Json -Depth 5))
        [IO.File]::WriteAllText("$stage/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/New-NativeHugoUpdate.ps1", @'
param($WorkspaceRoot,$SourcePath,$NativeModule,$PreviousVersion)
$path="$WorkspaceRoot/site/go.mod"
$expected=(Get-FileHash $path).Hash.ToLowerInvariant()
if(Test-Path "$WorkspaceRoot/simulate-stale-snapshot"){ $expected='0'*64 }
[pscustomobject]@{Files=[ordered]@{'site/go.mod'=[Text.Encoding]::UTF8.GetBytes("module fixture`nrequire $($NativeModule.path) $($NativeModule.version)`n")};ExpectedHashes=[ordered]@{'site/go.mod'=$expected};Sum='fixture-sum';GoModSum='fixture-mod-sum'}
'@)
        [IO.Compression.ZipFile]::CreateFromDirectory($stage,"$assets/OpenGuidePlatform-GuideSite.zip")
        $manifest=@{nativeHugoModule=@{path='github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides';version="v$version";sourceCommit=('a'*40)};schemaVersion=1;product='OpenGuidePlatform';version=$version;sourceCommit=('a'*40);channel=if($version.Contains('-')){'preview'}else{'stable'};archive='OpenGuidePlatform-GuideSite.zip';sha256=(Get-FileHash "$assets/OpenGuidePlatform-GuideSite.zip").Hash.ToLowerInvariant()}
        [IO.File]::WriteAllText("$assets/release-manifest.json",(ConvertTo-PackageManifest $manifest|ConvertTo-Json -Depth 10))
        $global:OgpBootstrapAssets["v$version"]=$assets
    }
}
Describe 'Guide-site installation and update' {
    BeforeEach {
        Mock Invoke-RestMethod { [IO.File]::ReadAllText($resolver) }
        $global:OgpBootstrapOffline=$false
        $global:OgpLockFailure=$false
        $global:OgpNoLockFile=$false
        $global:OgpVerificationFailure=$false
        $global:OgpUseRealLock=$false
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($workspace)|Out-Null
        & git init -q -b codex/adoption $workspace
        [IO.Directory]::CreateDirectory("$workspace/site")|Out-Null
        [IO.File]::WriteAllText("$workspace/site/go.mod",'module fixture')
        [IO.File]::WriteAllText("$workspace/site/hugo.yaml",'baseURL: https://example.test/')
        $parameters=@{WorkspaceRoot=$workspace;ReleaseTag='v1.2.3-Preview.1'}
    }
    AfterEach {
        # The installed fixture imports a fake Build module; do not leak it into other tests.
        Get-Module OpenGuidePlatform.PowerShell.GuideSiteBuild,OpenGuidePlatform.PowerShell.GuideSiteAdoption,OpenGuidePlatform.PowerShell.Core -All | Where-Object { $_.Path.StartsWith($TestDrive+[IO.Path]::DirectorySeparatorChar) } | Remove-Module -Force
    }
    It 'installs a minor preview selection and records a floating caller with exact installed identity' {
        & $bootstrap -Install -WorkspaceRoot $workspace -ReleaseTag v1.2
        $settings=Get-Content "$workspace/.OpenGuidePlatform/settings.yaml" -Raw|ConvertFrom-Yaml
        $settings.platform.version|Should -Be v1.2
        $settings.platform.ring|Should -Be preview
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json
        $record.releaseTag|Should -Be v1.2.3-Preview.2
        $record.workflowReference|Should -Be v1.2-preview
        $record.managedFiles.PSObject.Properties.Name|Should -Not -Contain '.OpenGuidePlatform/settings.yaml'
        Get-Content "$workspace/.github/workflows/main.yaml" -Raw|Should -Match '@v1.2-preview'
        & "$workspace/build.ps1" -Target production|Should -Be 'GuideSite|1.2.3-Preview.2|production|site'
    }
    It 'preserves a configured minor family when remote bootstrap changes only its channel' {
        & $bootstrap -Install -WorkspaceRoot $workspace -ReleaseTag v1.2
        & $bootstrap -Update -WorkspaceRoot $workspace -Channel stable
        $settings=& $resolver -WorkspaceRoot $workspace -ReadSettings
        $settings.platform.version|Should -Be v1.2
        $settings.platform.ring|Should -Be production
        (Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json).workflowReference|Should -Be v1.2
    }
    It 'selects the same newer minor-family release locally and in CI without changing the installation' {
        & $bootstrap -Install @parameters
        # Model a previously installed family whose next release became available afterwards.
        $settings=Get-Content "$workspace/.OpenGuidePlatform/settings.yaml" -Raw|ConvertFrom-Yaml
        $settings.platform.version='v1.2'
        $settings|ConvertTo-Yaml|Set-Content "$workspace/.OpenGuidePlatform/settings.yaml"
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json
        $record.workflowReference='v1.2-preview'
        $record|ConvertTo-Json -Depth 30|Set-Content "$workspace/.OpenGuidePlatform/installation.json"
        $before=(Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash
        $local=& $resolver -WorkspaceRoot $workspace
        $ci=& $resolver -WorkspaceRoot $workspace -FromWorkflow -OutputPath '.processing/ci-platform'
        (Get-Content "$local/platform.json" -Raw|ConvertFrom-Json).version|Should -Be '1.2.3-Preview.2'
        (Get-Content "$ci/platform.json" -Raw|ConvertFrom-Json).version|Should -Be '1.2.3-Preview.2'
        (Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash|Should -Be $before
    }
    It 'migrates legacy delivery during upgrade without putting editable settings in the record hashes' {
        & $bootstrap -Install @parameters
        Remove-Item "$workspace/.OpenGuidePlatform/settings.yaml"
        Set-Content "$workspace/.OpenGuidePlatform/delivery.yaml" "canary:`n  url: https://example-{pr}.test/`n  environment: '{pr}'`nproduction:`n  url: https://example.test/`n  environment: production"
        & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2
        $settings=Get-Content "$workspace/.OpenGuidePlatform/settings.yaml" -Raw|ConvertFrom-Yaml
        $settings.platform.version|Should -Be v1.2.3-Preview.2
        $settings.site.source|Should -Be site
        $settings.delivery.canary.url|Should -Be 'https://example-{pr}.test/'
        $settings.delivery.production.environment|Should -Be production
        Test-Path "$workspace/.OpenGuidePlatform/delivery.yaml"|Should -BeFalse
        Test-Path "$workspace/.OpenGuidePlatform/installation.json"|Should -BeTrue
    }
    It 'restores legacy delivery and installation if locking fails during settings migration' {
        & $bootstrap -Install @parameters
        Remove-Item "$workspace/.OpenGuidePlatform/settings.yaml"
        Set-Content "$workspace/.OpenGuidePlatform/delivery.yaml" "production:`n  url: https://example.test/"
        $before=(Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash
        $delivery=(Get-FileHash "$workspace/.OpenGuidePlatform/delivery.yaml").Hash
        $global:OgpLockFailure=$true
        {& $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2}|Should -Throw '*Actions locking failed*'
        Test-Path "$workspace/.OpenGuidePlatform/settings.yaml"|Should -BeFalse
        (Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash|Should -Be $before
        (Get-FileHash "$workspace/.OpenGuidePlatform/delivery.yaml").Hash|Should -Be $delivery
    }
    It 'preserves edited settings and prevents contradictory legacy delivery migration' {
        & $bootstrap -Install @parameters
        Add-Content "$workspace/.OpenGuidePlatform/settings.yaml" '# preserve this note'
        $before=[IO.File]::ReadAllText("$workspace/.OpenGuidePlatform/settings.yaml")
        & $bootstrap -Update @parameters
        [IO.File]::ReadAllText("$workspace/.OpenGuidePlatform/settings.yaml")|Should -BeExactly $before
        $data=Get-Content "$workspace/.OpenGuidePlatform/settings.yaml" -Raw|ConvertFrom-Yaml
        $data.delivery.production=@{url='https://new.test/'}
        $data|ConvertTo-Yaml|Set-Content "$workspace/.OpenGuidePlatform/settings.yaml"
        Set-Content "$workspace/.OpenGuidePlatform/delivery.yaml" "production:`n  url: https://old.test/"
        {& $bootstrap -Update @parameters}|Should -Throw '*Conflicting delivery settings*'
    }
    It 'resumes local stages from the prepared package without another release lookup' {
        & $bootstrap -Install -WorkspaceRoot $workspace -ReleaseTag v1.2
        $platform=& "$workspace/.OpenGuidePlatform/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $workspace
        New-Item -ItemType Directory "$workspace/.processing/evidence"|Out-Null
        @{version='1.2.3-Preview.2';sourceCommit=('a'*40);platformRoot=[IO.Path]::GetRelativePath($workspace,$platform).Replace('\','/')}|ConvertTo-Json|Set-Content "$workspace/.processing/evidence/platform-context.json"
        $global:OgpBootstrapOffline=$true
        & "$workspace/build.ps1" Build -OutputPath .processing/evidence -Target production|Should -Be 'GuideSite|1.2.3-Preview.2|production|site'
        & "$workspace/build.ps1" Validate -OutputPath .processing/evidence -Target production|Should -Be 'GuideSite|1.2.3-Preview.2|production|site'
    }
    It 'installs matching workflow and identical root agent shims without requiring a policy file' {
        & $bootstrap -Install @parameters
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json
        $record.releaseTag | Should -Be 'v1.2.3-Preview.1'
        $record.nativeHugoModule.version | Should -Be 'v1.2.3-Preview.1'
        $record.managedFiles.PSObject.Properties.Name | Should -Not -Contain 'site/go.mod'
        $record.managedFiles.PSObject.Properties.Name | Should -Not -Contain '.github/workflows/main.yaml'
        $record.workflowCallers.PSObject.Properties.Name | Should -Contain '.github/workflows/main.yaml'
        Get-Content "$workspace/site/go.mod" -Raw | Should -Match 'v1.2.3-Preview.1'
        Get-Content "$workspace/.github/workflows/main.yaml" -Raw | Should -Match '@v1.2.3-Preview.1'
        Test-Path "$workspace/.agents/skills/guide.transcreate/SKILL.md" | Should -BeTrue
        Test-Path "$workspace/.agents/skills/skills" | Should -BeFalse
        Test-Path "$workspace/.agents/skills/instructions" | Should -BeFalse
        (Get-FileHash "$workspace/AGENTS.md").Hash | Should -Be (Get-FileHash "$workspace/CLAUDE.md").Hash
        Test-Path "$workspace/guide-site.policy.json" | Should -BeFalse
    }
    It 'updates all managed identities to a selected release' {
        & $bootstrap -Install @parameters
        & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2
        (Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json).releaseTag | Should -Be 'v1.2.3-Preview.2'
        Get-Content "$workspace/.github/workflows/main.yaml" -Raw | Should -Match '@v1.2.3-Preview.2'
    }
    It 'preserves customised build and cleanup callers byte-for-byte except release references' {
        & $bootstrap -Install @parameters
        $path="$workspace/.github/workflows/main.yaml"
        $custom=[IO.File]::ReadAllText($path).Replace('  push:',"  merge_group:`n  push:").Replace('      deploy: false','      deploy: true')
        $custom += "`nconcurrency:`n  group: site-preview`n  cancel-in-progress: true`n"
        [IO.File]::WriteAllText($path,$custom)
        $cleanup=@'
name: Cleanup
on: [pull_request]
jobs:
  close:
    uses: 'nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-close-pr.yaml@v1.2.3-Preview.1' # keep comment
    secrets:
      static-web-app-token: ${{ secrets.SITE_TOKEN }}
'@
        [IO.File]::WriteAllText("$workspace/.github/workflows/cleanup.yml",$cleanup)
        & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2
        [IO.File]::ReadAllText($path) | Should -BeExactly $custom.Replace('@v1.2.3-Preview.1','@v1.2.3-Preview.2')
        [IO.File]::ReadAllText("$workspace/.github/workflows/cleanup.yml") | Should -BeExactly $cleanup.Replace('@v1.2.3-Preview.1','@v1.2.3-Preview.2')
    }
    It 'migrates a customised legacy managed caller without accepting edits to other managed files' {
        & $bootstrap -Install @parameters
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json -AsHashtable
        $record.Remove('workflowCallers')
        $record.managedFiles['.github/workflows/main.yaml']='0'*64
        $record|ConvertTo-Json -Depth 30|Set-Content "$workspace/.OpenGuidePlatform/installation.json"
        Add-Content "$workspace/.github/workflows/main.yaml" '# Site customisation'
        & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2
        $updated=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json -AsHashtable
        $updated.managedFiles.ContainsKey('.github/workflows/main.yaml') | Should -BeFalse
        Get-Content "$workspace/.github/workflows/main.yaml" -Raw | Should -Match '# Site customisation'
    }
    It 'rolls back callers native dependency and lockfile if locking fails' {
        & $bootstrap -Install @parameters
        $paths=@('.github/workflows/main.yaml','.github/workflows/actions.lock','site/go.mod','.OpenGuidePlatform/installation.json','build.ps1')
        $before=@{};foreach($path in $paths){$before[$path]=(Get-FileHash "$workspace/$path").Hash}
        $global:OgpLockFailure=$true
        { & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2 } | Should -Throw '*Actions locking failed*'
        foreach($path in $paths){(Get-FileHash "$workspace/$path").Hash | Should -Be $before[$path]}
    }
    It 'refuses a conflicting caller version without changing the installation' {
        & $bootstrap -Install @parameters
        $path="$workspace/.github/workflows/main.yaml"
        [IO.File]::WriteAllText($path,[IO.File]::ReadAllText($path).Replace('@v1.2.3-Preview.1','@v9.0.0'))
        $before=(Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash
        { & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2 } | Should -Throw '*Conflicting OGP caller version*'
        (Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash | Should -Be $before
    }
    It 'rolls back when supported action verification fails' {
        & $bootstrap -Install @parameters
        $before=(Get-FileHash "$workspace/.github/workflows/actions.lock").Hash
        $record=(Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash
        $global:OgpVerificationFailure=$true
        { & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2 } | Should -Throw '*Actions lockfile verification failed*'
        (Get-FileHash "$workspace/.github/workflows/actions.lock").Hash | Should -Be $before
        (Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash | Should -Be $record
    }
    It 'installs and upgrades reusable-only callers without an actions lockfile' {
        $global:OgpNoLockFile=$true
        & $bootstrap -Install @parameters
        Test-Path "$workspace/.github/workflows/actions.lock" | Should -BeFalse
        & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2
        (Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json).releaseTag | Should -Be 'v1.2.3-Preview.2'
        Test-Path "$workspace/.github/workflows/actions.lock" | Should -BeFalse
    }
    It 'installs and upgrades with released Actions locking while preserving caller settings' -Skip:($env:OGP_TEST_REAL_ACTIONS_LOCK -ne '1') {
        $global:OgpUseRealLock=$true
        & $bootstrap -Install @parameters
        Test-Path "$workspace/.github/workflows/actions.lock" | Should -BeFalse
        $path="$workspace/.github/workflows/main.yaml"
        $custom=[IO.File]::ReadAllText($path).Replace('  push:',"  merge_group:`n  push:")
        $custom=$custom.Replace('jobs:',@'
jobs:
  site-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
'@)
        [IO.File]::WriteAllText($path,$custom)
        & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2
        [IO.File]::ReadAllText($path) | Should -BeExactly $custom.Replace('@v1.2.3-Preview.1','@v1.2.3-Preview.2')
        $lock=Get-Content "$workspace/.github/workflows/actions.lock" -Raw|ConvertFrom-Yaml
        $lock.workflows['.github/workflows/main.yaml'] | Should -Contain 'actions/checkout@v4'
        (Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json).releaseTag | Should -Be 'v1.2.3-Preview.2'
    }
    It 'preserves an existing unrelated main workflow and refuses first installation' {
        New-Item -ItemType Directory "$workspace/.github/workflows" -Force | Out-Null
        Set-Content "$workspace/.github/workflows/main.yaml" 'name: Bespoke workflow'
        { & $bootstrap -Install @parameters } | Should -Throw '*Existing site workflow conflicts*'
        Test-Path "$workspace/build.ps1" | Should -BeFalse
    }
    It 'restores offline from the locked cache and runs the installed GuideSite entry point' {
        & $bootstrap -Install @parameters
        $global:OgpBootstrapOffline=$true
        & "$workspace/build.ps1" -Target preview | Should -Be 'GuideSite|1.2.3-Preview.1|preview|site'
    }
    It 'updates from the installed launcher without fetching remote bootstrap or loader source' {
        & $bootstrap -Install @parameters
        Mock Invoke-RestMethod { throw 'Installed update must not fetch bootstrap or loader source.' }
        & "$workspace/build.ps1" Update -ring preview -PlatformRelease v1.2.3-Preview.2
        (Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json).releaseTag | Should -Be 'v1.2.3-Preview.2'
        Test-Path "$workspace/bootstrap.ps1" | Should -BeFalse
    }
    It 'previews a local update without changing the installation record' {
        & $bootstrap -Install @parameters
        $before=(Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash
        & "$workspace/build.ps1" Update -ring preview -WhatIf
        (Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash | Should -Be $before
    }
    It 'retires an unchanged bootstrap managed by the previous installation' {
        & $bootstrap -Install @parameters
        [IO.File]::WriteAllText("$workspace/bootstrap.ps1",'# old managed bootstrap')
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json -AsHashtable
        $record.managedFiles['bootstrap.ps1']=(Get-FileHash "$workspace/bootstrap.ps1").Hash.ToLowerInvariant()
        $record|ConvertTo-Json -Depth 30|Set-Content "$workspace/.OpenGuidePlatform/installation.json"
        & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2
        Test-Path "$workspace/bootstrap.ps1" | Should -BeFalse
        (Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json -AsHashtable).managedFiles.ContainsKey('bootstrap.ps1') | Should -BeFalse
    }
    It 'preserves a modified legacy bootstrap and refuses the entire update' {
        & $bootstrap -Install @parameters
        [IO.File]::WriteAllText("$workspace/bootstrap.ps1",'# consumer modification')
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json -AsHashtable
        $record.managedFiles['bootstrap.ps1']='0'*64
        $record|ConvertTo-Json -Depth 30|Set-Content "$workspace/.OpenGuidePlatform/installation.json"
        $before=(Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash
        { & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2 } | Should -Throw '*Managed-file conflicts*bootstrap.ps1*'
        (Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash | Should -Be $before
        Get-Content "$workspace/bootstrap.ps1" -Raw | Should -Be '# consumer modification'
    }
    It 'restores the retired bootstrap and previous files when an update write fails' {
        & $bootstrap -Install @parameters
        [IO.File]::WriteAllText("$workspace/bootstrap.ps1",'# old managed bootstrap')
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json -AsHashtable
        $record.managedFiles['bootstrap.ps1']=(Get-FileHash "$workspace/bootstrap.ps1").Hash.ToLowerInvariant()
        $record|ConvertTo-Json -Depth 30|Set-Content "$workspace/.OpenGuidePlatform/installation.json"
        $before=(Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash
        $buildBefore=(Get-FileHash "$workspace/build.ps1").Hash
        $package=& $resolver -WorkspaceRoot $workspace -PlatformRelease v1.2.3-Preview.2
        Get-Module OpenGuidePlatform.PowerShell.GuideSiteAdoption -All | Remove-Module -Force
        Import-Module "$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/OpenGuidePlatform.PowerShell.GuideSiteAdoption.psm1" -Force
        $global:OgpWriteFailed=$false
        Mock New-Item -ModuleName OpenGuidePlatform.PowerShell.GuideSiteAdoption -ParameterFilter { $Path -like '*CLAUDE.md' } {
            if(-not $global:OgpWriteFailed){$global:OgpWriteFailed=$true;throw 'Simulated update write failure.'}
            Microsoft.PowerShell.Management\New-Item -ItemType SymbolicLink -Path $Path -Target '.agents/agents.md' -WhatIf:$false
        }
        { Invoke-GuideSiteAdoption -PackageRoot $package -WorkspaceRoot $workspace -Update } | Should -Throw '*Simulated update write failure*'
        (Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash | Should -Be $before
        (Get-FileHash "$workspace/build.ps1").Hash | Should -Be $buildBefore
        Get-Content "$workspace/bootstrap.ps1" -Raw | Should -Be '# old managed bootstrap'
    }
    It 'rejects modified managed files before changing any tracked file' {
        & $bootstrap -Install @parameters
        $before=[IO.File]::ReadAllText("$workspace/.OpenGuidePlatform/installation.json")
        [IO.File]::AppendAllText("$workspace/build.ps1",'# consumer edit')
        { & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2 } | Should -Throw '*Managed-file conflicts*'
        [IO.File]::ReadAllText("$workspace/.OpenGuidePlatform/installation.json") | Should -Be $before
    }
    It 'refuses existing consumer instructions without partial installation' {
        [IO.File]::WriteAllText("$workspace/AGENTS.md",'Consumer instructions')
        { & $bootstrap -Install @parameters } | Should -Throw '*Managed-file conflicts*'
        Test-Path "$workspace/build.ps1" | Should -BeFalse
        [IO.File]::ReadAllText("$workspace/AGENTS.md") | Should -Be 'Consumer instructions'
        [IO.File]::ReadAllText("$workspace/site/go.mod") | Should -Be 'module fixture'
    }
    It 'refuses stale native snapshots before writing any managed files' {
        [IO.File]::WriteAllText("$workspace/simulate-stale-snapshot",'fixture')
        { & $bootstrap -Install @parameters } | Should -Throw '*Consumer file changed during native update*'
        Test-Path "$workspace/build.ps1" | Should -BeFalse
        [IO.File]::ReadAllText("$workspace/site/go.mod") | Should -Be 'module fixture'
    }
    It 'previews installation without writing managed files' {
        & $bootstrap -Install @parameters -WhatIf
        Test-Path "$workspace/build.ps1" | Should -BeFalse
        Test-Path "$workspace/.OpenGuidePlatform/installation.json" | Should -BeFalse
        [IO.File]::ReadAllText("$workspace/site/go.mod") | Should -Be 'module fixture'
    }
    It 'previews automatic installation on main without creating a branch or changing managed files' {
        & git -C $workspace symbolic-ref HEAD refs/heads/main
        & $bootstrap @parameters -WhatIf
        (& git -C $workspace branch --show-current).Trim() | Should -Be main
        @(& git -C $workspace for-each-ref refs/heads/codex/ --format='%(refname)').Count | Should -Be 0
        Test-Path "$workspace/build.ps1" | Should -BeFalse
        Test-Path "$workspace/.OpenGuidePlatform/installation.json" | Should -BeFalse
        [IO.File]::ReadAllText("$workspace/site/go.mod") | Should -Be 'module fixture'
    }
    It 'creates the automatic review branch only after successful preflight' {
        & git -C $workspace symbolic-ref HEAD refs/heads/main
        [IO.File]::WriteAllText("$workspace/AGENTS.md",'Consumer instructions')
        { & $bootstrap @parameters } | Should -Throw '*Managed-file conflicts*'
        (& git -C $workspace branch --show-current).Trim() | Should -Be main
        [IO.File]::Delete("$workspace/AGENTS.md")
        & $bootstrap @parameters
        (& git -C $workspace branch --show-current).Trim() | Should -Match '^codex/platform-adoption-'
        Test-Path "$workspace/.OpenGuidePlatform/installation.json" | Should -BeTrue
    }

    It 'migrates the verified legacy root resolver and record into .OpenGuidePlatform' {
        & $bootstrap -Install @parameters
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json -AsHashtable
        $record.managedFiles['Resolve-OpenGuidePlatform.ps1']=$record.managedFiles['.OpenGuidePlatform/Resolve-OpenGuidePlatform.ps1']
        $record.managedFiles.Remove('.OpenGuidePlatform/Resolve-OpenGuidePlatform.ps1')
        Move-Item "$workspace/.OpenGuidePlatform/Resolve-OpenGuidePlatform.ps1" "$workspace/Resolve-OpenGuidePlatform.ps1"
        $record|ConvertTo-Json -Depth 30|Set-Content "$workspace/open-guide-platform.installation.json"
        Remove-Item "$workspace/.OpenGuidePlatform/installation.json"
        & $bootstrap -Update -WorkspaceRoot $workspace -ReleaseTag v1.2.3-Preview.2
        Test-Path "$workspace/open-guide-platform.installation.json"|Should -BeFalse
        Test-Path "$workspace/Resolve-OpenGuidePlatform.ps1"|Should -BeFalse
        Test-Path "$workspace/.OpenGuidePlatform/Resolve-OpenGuidePlatform.ps1"|Should -BeTrue
        (Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json).sourcePath|Should -Be site
    }
    It 'rejects a corrupt cached archive instead of executing cached code' {
        & $bootstrap -Install @parameters
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json
        [IO.File]::AppendAllText("$workspace/.processing/platform-cache/$($record.release.packages.GuideSite.sha256)/OpenGuidePlatform-GuideSite.zip",'corrupt')
        { & $resolver -WorkspaceRoot $workspace } | Should -Throw '*Cached package digest mismatch*'
    }
    It 'selects an installable preview when no release tag is supplied' {
        & $bootstrap -Install -WorkspaceRoot $workspace
        (Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json).releaseTag | Should -Be 'v1.2.3-Preview.2'
    }
    It 'rejects unsafe source paths before modifying the site' {
        { & $bootstrap -Install @parameters -SourcePath '../outside' } | Should -Throw '*Unsafe installation path*'
    }
    It 'installs a production release and restores its installed pin' {
        & $bootstrap -Install -WorkspaceRoot $workspace -Channel stable -ReleaseTag v1.2.3
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json
        $record.releaseTag|Should -Be v1.2.3
        $record.release.channel|Should -Be stable
        Get-Content "$workspace/site/go.mod" -Raw|Should -Match 'Guides v1.2.3'
        $restored=& $resolver -WorkspaceRoot $workspace
        (Get-Content "$restored/platform.json" -Raw|ConvertFrom-Json).version|Should -Be '1.2.3'
    }
    It 'updates settings and callers together when an explicit package path is supplied' {
        & $bootstrap -Install @parameters
        $package=& $resolver -WorkspaceRoot $workspace -PlatformRelease v1.2.3-Preview.2
        Remove-Item "$package/platform-selection.json"
        & "$workspace/build.ps1" Update -PlatformPath $package
        $settings=& $resolver -WorkspaceRoot $workspace -ReadSettings
        $settings.platform.version|Should -Be v1.2.3-Preview.2
        (Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json).workflowReference|Should -Be v1.2.3-Preview.2
        & "$workspace/build.ps1" -Target preview|Should -Contain 'GuideSite|1.2.3-Preview.2|preview|site'
    }
    It 'rejects an exact preview selection labelled as production before restoration' {
        & $bootstrap -Install @parameters
        $path="$workspace/.OpenGuidePlatform/settings.yaml"
        (Get-Content $path -Raw).Replace('ring: preview','ring: production')|Set-Content $path
        {& $resolver -WorkspaceRoot $workspace}|Should -Throw '*exact OGP version belongs to the preview ring*'
    }
    It 'updates an installed preview to production through the local launcher' {
        & $bootstrap -Install @parameters
        & "$workspace/build.ps1" Update -ring production
        (Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json).releaseTag|Should -Be v1.2.3
        Get-Content "$workspace/site/go.mod" -Raw|Should -Match 'Guides v1.2.3'
        & "$workspace/build.ps1" -Target production | Should -Contain 'GuideSite|1.2.3|production|site'
    }
    It 'supports the no-argument remote execution entry point for install and update' {
        Push-Location $workspace
        try{
            Invoke-Expression ([IO.File]::ReadAllText($bootstrap))
            (Get-Content .OpenGuidePlatform/installation.json -Raw|ConvertFrom-Json).releaseTag | Should -Be 'v1.2.3-Preview.2'
            Invoke-Expression ([IO.File]::ReadAllText($bootstrap))
            (Get-Item AGENTS.md).LinkType | Should -Be SymbolicLink
        }finally{Pop-Location}
    }
    It 'resolves a specific release without installing or changing the branch' -ForEach @(@{Channel='preview';Tag='v1.2.3-Preview.2'},@{Channel='stable';Tag='v1.2.3'}) {
        & git -C $workspace symbolic-ref HEAD refs/heads/main
        $package=& $resolver -PlatformSource $(if($Channel -eq 'stable'){'Production'}else{'Preview'}) -PlatformRelease $Tag -WorkspaceRoot $workspace
        (Get-Content "$package/platform.json" -Raw|ConvertFrom-Json).version|Should -Be $Tag.Substring(1)
        Test-Path "$workspace/build.ps1"|Should -BeFalse
        (& git -C $workspace branch --show-current).Trim()|Should -Be main
    }
    It 'resolves latest within the requested channel' -ForEach @(@{Channel='preview';Expected='1.2.3-Preview.2'},@{Channel='stable';Expected='1.2.3'}) {
        $package=& $resolver -PlatformSource $(if($Channel -eq 'stable'){'Production'}else{'Preview'}) -WorkspaceRoot $workspace
        (Get-Content "$package/platform.json" -Raw|ConvertFrom-Json).version|Should -Be $Expected
        Test-Path "$workspace/.OpenGuidePlatform/installation.json"|Should -BeFalse
    }
    It 'lets the installed launcher select local platform code without updating the lock' {
        & $bootstrap -Install @parameters
        $before=(Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash
        & "$workspace/build.ps1" -PlatformPath "$TestDrive/1.2.3-Preview.2/package" -Target preview|Should -Be 'GuideSite|1.2.3-Preview.2|preview|site'
        (Get-FileHash "$workspace/.OpenGuidePlatform/installation.json").Hash|Should -Be $before
    }
    It 'requires a review branch'  {
        & git -C $workspace symbolic-ref HEAD refs/heads/main
        { & $bootstrap -Install @parameters } | Should -Throw '*review branch*'
    }
}
AfterAll { Remove-Item Function:/global:gh -ErrorAction SilentlyContinue; Remove-Variable OgpBootstrapAssets,OgpBootstrapOffline,OgpWriteFailed -Scope Global -ErrorAction SilentlyContinue }
