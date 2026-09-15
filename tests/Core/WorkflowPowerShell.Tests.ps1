BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module powershell-yaml
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1"
}
Describe 'Thin PowerShell workflow adapters' {
    It 'keeps authored pipeline code in PowerShell files' {
        $files=@(Get-ChildItem "$root/.github/workflows" -File | Where-Object Extension -In '.yml','.yaml')+@(Get-Item "$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/main.yaml")
        foreach($file in $files){
            $workflow=Get-Content $file.FullName -Raw|ConvertFrom-Yaml
            if($workflow -isnot [Collections.IDictionary] -or -not $workflow.Contains('jobs')){
                throw (New-PlatformBuildFailure -Subject $file.Name -Why "The workflow check tried to read '$($file.Name)' as a workflow, but it has no jobs. A dependency lockfile describes dependencies, not build jobs." -HowToFix 'Scan only .yml and .yaml workflow files; exclude actions.lock and other support files. If this is an intended workflow, restore its jobs mapping.')
            }
            foreach($job in $workflow.jobs.Values){foreach($step in $job['steps']){
                if($step['uses'] -match 'actions/github-script' -or ($step['with'] -and $step['with']['script'])){
                    throw (New-PlatformBuildFailure -Why "Workflow '$($file.Name)' contains inline script logic instead of calling the PowerShell build module." -HowToFix 'Move that operation into the appropriate PowerShell build module and replace the workflow script with a call to its entry point.')
                }
                $(if($step['with']){$step['with']['script']})|Should -BeNullOrEmpty -Because $file.Name
                if($step['run']){
                    if($step['run'].Trim() -match '[\r\n]' -or $step['run'] -match '(?i)^\s*(if|foreach|switch|function|while|const|let)\b'){
                        throw (New-PlatformBuildFailure -Why "Workflow '$($file.Name)' implements build logic inside a pipeline step, so it cannot be reused directly by the local build." -HowToFix 'Move the step implementation into the PowerShell build module and replace the run block with a single call to that operation.')
                    }
                }
            }}
        }
    }
    It 'closes only the environment belonging to the closed pull request' {
        $workflow=Get-Content "$root/.github/workflows/guide-site-close-pr.yaml" -Raw|ConvertFrom-Yaml
        $step=@($workflow.jobs.Values.steps|Where-Object { $_['uses'] -like 'Azure/*' })[0]
        $workflow.on.workflow_call.inputs['deployment-environment'].type|Should -Be string
        $workflow.on.workflow_call.inputs['deployment-environment'].required|Should -BeFalse
        $workflow.on.workflow_call.inputs['deployment-environment'].default|Should -Be ''
        $step.with.deployment_environment|Should -Be '${{ inputs.deployment-environment || github.event.pull_request.number }}'
        $workflow.jobs.close.if|Should -Be '${{ github.event_name == ''pull_request'' && github.event.action == ''closed'' }}'
    }
}
