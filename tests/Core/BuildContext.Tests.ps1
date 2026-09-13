BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
}
Describe 'Build context policy' {
    It 'keeps release-labelled pull requests out of production' {
        $context=Get-GuideBuildContext -EventName pull_request -PullRequestNumber 35 -PreReleaseLabel ''
        $context.Target | Should -Be canary
        $context.DeploymentEnvironment | Should -Be canary-35
        {Get-GuideBuildContext -EventName pull_request} | Should -Throw '*positive PR number*'
    }
    It 'keeps merge queue candidates isolated from production' {
        (Get-GuideBuildContext -EventName merge_group).Target | Should -Be canary
    }
    It 'preserves preview and stable push selection' {
        (Get-GuideBuildContext -EventName push -PreReleaseLabel Preview).Target | Should -Be preview
        (Get-GuideBuildContext -EventName push).DeploymentEnvironment | Should -Be ''
        (Get-GuideBuildContext -EventName push -ProductionEnvironment staging).DeploymentEnvironment | Should -Be staging
    }
    It 'treats unknown labels as canary and refuses output injection' {
        (Get-GuideBuildContext -EventName workflow_dispatch -PreReleaseLabel "Preview`nTarget=production").Target | Should -Be canary
        {Get-GuideBuildContext -EventName push -ProductionEnvironment "production`nInjected=true"} | Should -Throw
    }
    It 'writes matching local and Actions context without evaluating label text' {
        $output=Join-Path $TestDrive 'outputs.txt'
        $summary=Join-Path $TestDrive 'summary.md'
        $context=& (Join-Path $root '.build/Write-PlatformRunContext.ps1') -EventName pull_request -PullRequestNumber 35 -OutputPath $output -SummaryPath $summary
        $context.Target | Should -Be canary
        (Get-Content $output) | Should -Contain 'AzureSitesConfig=canary'
        (Get-Content $summary -Raw) | Should -Match 'Deployment remains disabled'
    }
}