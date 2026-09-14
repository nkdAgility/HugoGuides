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
    function global:gh {
        $global:LASTEXITCODE=0
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
            $pattern=$args[[Array]::IndexOf($args,'--pattern')+1]
            [IO.File]::Copy((Join-Path $global:OgpBootstrapAssets[$args[2]] $pattern),(Join-Path $directory $pattern))
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
        Get-Module OpenGuidePlatform.PowerShell.GuideSiteBuild,OpenGuidePlatform.PowerShell.GuideSiteAdoption -All | Where-Object { $_.Path.StartsWith($TestDrive+[IO.Path]::DirectorySeparatorChar) } | Remove-Module -Force
    }
    It 'installs matching workflow and identical root agent shims without requiring a policy file' {
        & $bootstrap -Install @parameters
        $record=Get-Content "$workspace/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json
        $record.releaseTag | Should -Be 'v1.2.3-Preview.1'
        $record.nativeHugoModule.version | Should -Be 'v1.2.3-Preview.1'
        $record.managedFiles.PSObject.Properties.Name | Should -Not -Contain 'site/go.mod'
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
    It 'rejects stable adoption and unsafe source paths before modifying the site' {
        { & $bootstrap -Install -WorkspaceRoot $workspace -Channel stable -ReleaseTag v1.2.3 } | Should -Throw '*Stable adoption is not available*'
        { & $bootstrap -Install @parameters -SourcePath '../outside' } | Should -Throw '*Unsafe installation path*'
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
