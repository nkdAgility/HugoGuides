BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module powershell-yaml -MinimumVersion 0.4.12
}
Describe 'Merge-queue acceptance' {
    It 'runs the same candidate pipeline for merge groups without deploying or releasing them' {
        $main=Get-Content "$root/.github/workflows/main.yaml" -Raw|ConvertFrom-Yaml
        $main.on.merge_group.types | Should -Contain checks_requested
        $main.jobs.sample.with.deploy | Should -Match "github.event_name != 'merge_group'"
        $main.jobs.release['if'] | Should -Be '${{ github.event_name == ''push'' }}'
        $main.jobs.sample.needs | Should -Be build
    }
}

Describe 'Guide-site release tag triggers' {
    It 'routes version tags through the existing shared guide-site pipeline' {
        $caller=Get-Content "$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/main.yaml" -Raw|ConvertFrom-Yaml
        $caller.on.push.branches|Should -Contain main
        $caller.on.pull_request.branches|Should -Contain main
        $caller.on.push.tags|Should -Contain 'v[0-9]*'
        $caller.on.push.tags|Should -Contain '[0-9]*'
        $caller.jobs.Count|Should -Be 1
        $caller.jobs['guide-site'].uses|Should -Match 'guide-site-build.yaml@__RELEASE__$'
        $caller.jobs['guide-site'].with['source-ref']|Should -Be '${{ github.event.pull_request.head.sha || github.sha }}'
        $caller.jobs['guide-site'].with.ContainsKey('target')|Should -BeFalse
    }
}