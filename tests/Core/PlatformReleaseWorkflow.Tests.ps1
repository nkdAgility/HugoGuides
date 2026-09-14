BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module powershell-yaml -MinimumVersion 0.4.12
    $workflow=Get-Content "$root/.github/workflows/main.yaml" -Raw|ConvertFrom-Yaml
}
Describe 'Platform release event eligibility' {
    It 'builds stable and prerelease root tags without recursing on Hugo module tags' {
        $filters=@($workflow.on.push.tags)
        foreach($tag in @('v0.5.3','v0.5.3-Preview.1')){
            @($filters|Where-Object {$tag -like $_}).Count|Should -BeGreaterThan 0
        }
        @($filters|Where-Object {'system/OpenGuidePlatform.Hugo.Guides/v0.5.3' -like $_}).Count|Should -Be 0
    }
    It 'gates publication on sample success and excludes PR and merge-group events' {
        $workflow.jobs.release.needs|Should -Contain 'build'
        $workflow.jobs.release.needs|Should -Contain 'sample'
        # Exact event whitelist is deliberate: versions choose the channel, not publication permission.
        $workflow.jobs.release.if|Should -Be '${{ github.event_name == ''push'' }}'
    }
}
