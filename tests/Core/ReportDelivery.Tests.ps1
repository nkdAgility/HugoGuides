BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
}
Describe 'Assessment delivery is independent of validation' {
    BeforeEach {
        $assessment=@{
            schemaVersion=1;sourceCommit=('a'*40);platformVersion='0.0.0';policyDigest=$null
            target='preview';stage='Prepare';outcome='blocked'
            findings=@(@{code='PREPARE_INPUT_UNAVAILABLE';severity='blocker';scope='platform';subject='Inputs';message='Missing policy';remediation='Restore policy';evidence=@()})
            inventory=@{wrapper=@{state='unknown';languages=@()};guides=@()}
        }
    }
    It 'delivers blocked findings without turning their assessment into a pass' {
        $path=Join-Path $TestDrive 'summary.md'
        (Write-GuideAssessmentSummary $assessment $path).Outcome | Should -Be delivered
        $assessment.outcome | Should -Be blocked
        Get-Content $path -Raw | Should -Match 'Prepare: blocked'
        Get-Content $path -Raw | Should -Match 'Restore policy'
    }
    It 'preserves existing summary content' {
        $path=Join-Path $TestDrive 'existing.md'
        [IO.File]::WriteAllText($path,'Earlier step')
        (Write-GuideAssessmentSummary $assessment $path).Outcome | Should -Be delivered
        Get-Content $path -Raw | Should -Match '^Earlier step\r?\n## Prepare'
    }
    It 'reports storage failure separately without changing findings' {
        $before=$assessment|ConvertTo-Json -Depth 100
        $delivery=Write-GuideAssessmentSummary $assessment $TestDrive
        $delivery.Outcome | Should -Be failed
        $delivery.Code | Should -Be REPORT_DELIVERY_FAILED
        ($assessment|ConvertTo-Json -Depth 100) | Should -Be $before
    }
    It 'refuses invalid success evidence before writing' {
        $assessment.outcome='pass'
        $path=Join-Path $TestDrive 'invalid.md'
        (Write-GuideAssessmentSummary $assessment $path).Outcome | Should -Be failed
        Test-Path $path | Should -BeFalse
    }
    It 'still delivers blocked analysis when immutable local report storage is occupied' {
        $workspace=Join-Path $TestDrive 'workspace'
        [IO.Directory]::CreateDirectory((Join-Path $workspace '.processing/occupied'))|Out-Null
        $summary=Join-Path $TestDrive 'entry-summary.md'
        { & (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/GuideSiteBuild/Prepare-GuideSite.ps1') -WorkspaceRoot $workspace -PolicyPath (Join-Path $workspace 'missing.json') -SourceCommit ('a'*40) -OutputPath '.processing/occupied' -SummaryPath $summary } | Should -Throw '*REPORT_DELIVERY_FAILED*assessment remains blocked*'
        Get-Content $summary -Raw | Should -Match 'PREPARE_INPUT_UNAVAILABLE'
    }
}