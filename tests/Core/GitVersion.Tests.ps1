BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/Versioning/GitVersion.ps1"
    $tool=Join-Path $root ('.processing/tools/gitversion/'+$(if($IsWindows){'dotnet-gitversion.exe'}else{'dotnet-gitversion'}))
    function Get-FixtureVersion {
        $start=[Diagnostics.ProcessStartInfo]::new($tool)
        $start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
        $start.Environment['DOTNET_ROLL_FORWARD']='Major'
        foreach($key in @('GITHUB_ACTIONS','GITHUB_REF','GITHUB_HEAD_REF','GITHUB_REPOSITORY','TF_BUILD','TEAMCITY_VERSION','JENKINS_URL','APPVEYOR','BUILD_BUILDID','BUILD_SOURCEBRANCH')){$start.Environment.Remove($key)|Out-Null}
        foreach($argument in @($fixture,'/config',"$fixture/GitVersion.yml",'/output','json','/nofetch','/nonormalize')){$start.ArgumentList.Add($argument)}
        $process=[Diagnostics.Process]::Start($start)
        $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)){$process.Kill($true);throw 'GitVersion fixture timed out.'}
        $raw=$stdout.GetAwaiter().GetResult();$errorText=$stderr.GetAwaiter().GetResult()
        if($process.ExitCode -ne 0){throw "GitVersion fixture failed: $raw $errorText"}
        $process.Dispose()
        $raw|ConvertFrom-Json
    }
    function Add-FixtureCommit([string]$Message){
        & git -C $fixture -c user.name=Test -c user.email=test@example.test commit --allow-empty -qm $Message
        if($LASTEXITCODE){throw 'Fixture commit failed.'}
    }
}
Describe 'GitVersion 6 configuration migration' {
    It 'converts old keys and preserves explicit site settings' {
        $legacy="mode: ContinuousDeployment`ncontinuous-delivery-fallback-tag: Canary`nnext-version: 3.2.1`ncommit-message-incrementing: MergeMessageOnly`nbranches:`n  main:`n    mode: ContinuousDeployment`n    tag: preview`n    is-mainline: true`n    prevent-increment-of-merged-branch-version: false`n    increment: Patch`n    regex: ^main$`n  release:`n    tag: ''`n    mode: ContinuousDelivery`n"
        $converted=ConvertTo-GuideGitVersion6Configuration $legacy|ConvertFrom-Yaml
        $converted['next-version']|Should -Be '3.2.1'
        $converted['commit-message-incrementing']|Should -Be MergeMessageOnly
        $converted.branches.main.label|Should -Be preview
        $converted.branches.main.mode|Should -Be ContinuousDelivery
        $converted.branches.main['prevent-increment']['of-merged-branch']|Should -BeFalse
        $converted.branches.release.mode|Should -Be ManualDeployment
        $converted.Contains('continuous-delivery-fallback-tag')|Should -BeFalse
        $converted.branches.main.Contains('tag')|Should -BeFalse
    }
    It 'accepts configuration that relies entirely on default branches under strict mode' {
        Set-StrictMode -Version Latest
        $text="next-version: 2.0.0`n"
        ConvertTo-GuideGitVersion6Configuration $text|Should -BeExactly $text
    }
    It 'preserves an explicitly configured main delivery mode through its equivalent v6 mode' {
        $text="branches:`n  main:`n    mode: ContinuousDelivery`n    tag: Preview`n"
        $converted=ConvertTo-GuideGitVersion6Configuration $text|ConvertFrom-Yaml
        $converted.branches.main.mode|Should -Be ManualDeployment
    }
    It 'leaves current configuration byte-identical including comments' {
        $text="# site-owned`nbranches:`n  main:`n    label: Preview`n"
        ConvertTo-GuideGitVersion6Configuration $text|Should -BeExactly $text
    }
}
Describe 'Real GitVersion commit histories' {
    BeforeEach {
        $fixture=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory $fixture|Out-Null
        git init -q -b main $fixture
        Copy-Item "$root/.github/GitVersion.yml" "$fixture/GitVersion.yml"
        Add-FixtureCommit 'Starting release'
        git -C $fixture tag v1.2.3
    }
    It 'calculates a version from migrated <site> configuration' -ForEach @(
        @{site='KanbanGuides';legacyMode='ContinuousDeployment';seed='0.0.1'},
        @{site='ScrumGuide-ExpansionPack';legacyMode='ContinuousDeployment';seed='1.0.0'},
        @{site='the-safe-delusion';legacyMode='ContinuousDelivery';seed='0.0.1'}
    ) {
        $legacy="assembly-versioning-scheme: MajorMinorPatch`nmode: $legacyMode`ncontinuous-delivery-fallback-tag: Canary`nnext-version: $seed`nbranches:`n  main:`n    regex: ^master$|^main$`n    mode: $legacyMode`n    tag: Preview`n    increment: Patch`n    is-mainline: true`n    prevent-increment-of-merged-branch-version: false`n    tracks-release-branches: true`n  release:`n    mode: ContinuousDelivery`n    tag: ''`n    increment: Patch`n    regex: ^release(s)?[\/-]`n    source-branches: [master, main]`n    is-release-branch: true`n    is-mainline: false`n"
        $configuration=ConvertTo-GuideGitVersion6Configuration $legacy|ConvertFrom-Yaml
        # Explicitly agreed for these three sites: every main build advances preview.
        # Generic Update preserves custom mode choices for other consumers.
        $configuration.branches.main.mode='ContinuousDelivery'
        $configuration|ConvertTo-Yaml|Set-Content "$fixture/GitVersion.yml"
        Add-FixtureCommit 'Ordinary change'
        $first=Get-FixtureVersion
        Add-FixtureCommit 'Another ordinary change'
        $second=Get-FixtureVersion
        $first.MajorMinorPatch|Should -Be '1.2.4'
        $second.PreReleaseNumber|Should -BeGreaterThan $first.PreReleaseNumber
        Add-FixtureCommit 'A capability +semver: minor'
        $version=Get-FixtureVersion
        $version.MajorMinorPatch|Should -Be '1.3.0'
        $version.PreReleaseLabel|Should -Be Preview
    }
    It 'keeps the exact release tag stable' {
        $version=Get-FixtureVersion
        $version.SemVer|Should -Be '1.2.3'
        $version.PreReleaseLabel|Should -Be ''
    }
    It 'increments the preview counter for successive ordinary main commits' {
        Add-FixtureCommit 'Correct a typo'
        $first=Get-FixtureVersion
        Add-FixtureCommit 'Improve an explanation'
        $second=Get-FixtureVersion
        $first.MajorMinorPatch|Should -Be '1.2.4'
        $second.MajorMinorPatch|Should -Be '1.2.4'
        $second.PreReleaseLabel|Should -Be Preview
        $second.PreReleaseNumber|Should -BeGreaterThan $first.PreReleaseNumber
    }
    It 'honors commit-message <directive>' -ForEach @(
        @{directive='patch';expected='1.2.4'},@{directive='fix';expected='1.2.4'},
        @{directive='minor';expected='1.3.0'},@{directive='feature';expected='1.3.0'},
        @{directive='major';expected='2.0.0'},@{directive='breaking';expected='2.0.0'}
    ) {
        Add-FixtureCommit "A change +semver: $directive"
        (Get-FixtureVersion).MajorMinorPatch|Should -Be $expected
    }
    It 'honors a bump carried in a merged commit' {
        git -C $fixture switch -qc codex/change
        Add-FixtureCommit 'New capability +semver: minor'
        git -C $fixture switch -q main
        git -C $fixture -c user.name=Test -c user.email=test@example.test merge --no-ff -qm 'Merge reviewed change' codex/change
        (Get-FixtureVersion).MajorMinorPatch|Should -Be '1.3.0'
    }
}
