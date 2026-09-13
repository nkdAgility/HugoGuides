BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
}
Describe 'Build context policy' {
    It 'keeps release-labelled pull requests out of production' {
        $context=Get-GuideBuildContext -EventName pull_request -PullRequestNumber 35 -PreReleaseLabel ''
        $context.Target | Should -Be preview
        $context.DeploymentEnvironment | Should -Be canary-35
        {Get-GuideBuildContext -EventName pull_request} | Should -Throw '*positive PR number*'
    }
    It 'keeps merge queue candidates isolated from production' {
        (Get-GuideBuildContext -EventName merge_group).Target | Should -Be preview
    }
    It 'preserves preview and stable push selection' {
        (Get-GuideBuildContext -EventName push -PreReleaseLabel Preview).Target | Should -Be preview
        (Get-GuideBuildContext -EventName push).DeploymentEnvironment | Should -Be ''
        (Get-GuideBuildContext -EventName push -ProductionEnvironment staging).DeploymentEnvironment | Should -Be staging
    }
    It 'treats unknown labels as canary and refuses output injection' {
        (Get-GuideBuildContext -EventName workflow_dispatch -PreReleaseLabel "Preview`nTarget=production").Target | Should -Be preview
        {Get-GuideBuildContext -EventName push -ProductionEnvironment "production`nInjected=true"} | Should -Throw
    }
}