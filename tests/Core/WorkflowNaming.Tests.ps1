BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module powershell-yaml -RequiredVersion 0.4.12
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