BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
    Import-Module powershell-yaml
}
Describe 'One GitVersion-selected delivery context' {
    It 'maps the existing GitVersion labels to delivery rings' -ForEach @(
        @{Label='';Ring='production'},@{Label='Preview';Ring='preview'},
        @{Label='preview';Ring='preview'},@{Label='Canary';Ring='canary'},@{Label='feature-fix';Ring='canary'}
    ) { Get-GuideDeliveryRing -PreReleaseLabel $Label|Should -Be $Ring }
    It 'does not allow canary or preview to select the production slot' -ForEach @('canary','preview') {
        {Resolve-GuideDeliveryContext -WorkspaceRoot $root -Target $_ -DeploymentEnvironment production}|Should -Throw '*non-production*'
    }
    It 'passes Prepare selection to every downstream stage' {
        $workflow=Get-Content "$root/.github/workflows/guide-site-build.yaml" -Raw|ConvertFrom-Yaml
        foreach($name in @('build','validate','deploy','verify')){
            $job=$workflow.jobs[$name]
            @($job.needs)|Should -Contain 'prepare'
            $job.env.SITE_TARGET|Should -Be '${{ needs.prepare.outputs.target }}'
            $job.env.SITE_BASE_URL|Should -Be '${{ needs.prepare.outputs.url }}'
        }
        $workflow.jobs.prepare.outputs.target|Should -Be '${{ steps.delivery.outputs.target }}'
        $workflow.jobs.deploy.needs|Should -Contain 'validate'
        $workflow.jobs.verify.needs|Should -Contain 'deploy'
    }
    It 'generates one shared workflow call without choosing the ring in the site' {
        $workflow=Get-Content "$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/main.yaml" -Raw|ConvertFrom-Yaml
        $workflow.jobs.Count|Should -Be 1
        $workflow.jobs['guide-site'].with.Contains('target')|Should -BeFalse
    }
}
