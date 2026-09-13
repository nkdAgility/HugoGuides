BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module powershell-yaml -MinimumVersion 0.4.12
}
Describe 'Required guide-site check identities' {
    It 'keeps stage names identical for preview and production' {
        $workflow=Get-Content "$root/.github/workflows/guide-site-build.yaml" -Raw|ConvertFrom-Yaml
        foreach($stage in @('Prepare','Build','Validate','Deploy','Verify')){
            $name=$workflow.jobs[$stage.ToLowerInvariant()].name
            # Site identity distinguishes consumers; environment must not change the required check.
            $name | Should -Be ('${{ inputs.site-name }} '+$stage)
            $name | Should -Not -Match 'inputs\.target|preview|production'
        }
    }
}
Describe 'Merge-queue acceptance' {
    It 'runs the same candidate pipeline for merge groups without deploying or releasing them' {
        $main=Get-Content "$root/.github/workflows/main.yaml" -Raw|ConvertFrom-Yaml
        $main.on.merge_group.types | Should -Contain checks_requested
        $main.jobs.sample.with.deploy | Should -Match "github.event_name != 'merge_group'"
        $main.jobs.release['if'] | Should -Be '${{ github.event_name == ''push'' && github.ref == ''refs/heads/main'' }}'
        $main.jobs.sample.needs | Should -Be build
    }
}
