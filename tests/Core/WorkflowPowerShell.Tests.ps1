BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module powershell-yaml
}
Describe 'Thin PowerShell workflow adapters' {
    It 'keeps authored pipeline code in PowerShell files' {
        $files=@(Get-ChildItem "$root/.github/workflows" -File)+@(Get-Item "$root/system/OpenGuidePlatform.GuideSite.Adoption/main.yaml")
        foreach($file in $files){
            $workflow=Get-Content $file.FullName -Raw|ConvertFrom-Yaml
            foreach($job in $workflow.jobs.Values){foreach($step in $job['steps']){
                $step['uses']|Should -Not -Match 'actions/github-script' -Because $file.Name
                $(if($step['with']){$step['with']['script']})|Should -BeNullOrEmpty -Because $file.Name
                if($step['run']){
                    $step['run'].Trim()|Should -Not -Match '[\r\n]' -Because 'workflow steps call scripts rather than implement them'
                    $step['run']|Should -Not -Match '(?i)^\s*(if|foreach|switch|function|while|const|let)\b' -Because $file.Name
                }
            }}
        }
    }
    It 'closes only the environment belonging to the closed pull request' {
        $workflow=Get-Content "$root/.github/workflows/guide-site-close-pr.yaml" -Raw|ConvertFrom-Yaml
        $step=@($workflow.jobs.Values.steps|Where-Object { $_['uses'] -like 'Azure/*' })[0]
        $step.with.deployment_environment|Should -Be '${{ github.event.pull_request.number }}'
        ($workflow.jobs.Values.if -join ' ')|Should -Match "closed"
    }
}
