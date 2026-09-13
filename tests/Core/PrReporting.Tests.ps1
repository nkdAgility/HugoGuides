BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
}
Describe 'Immutable PR assessment delivery' {
    BeforeEach {
        $assessment=@{schemaVersion=1;sourceCommit=('a'*40);platformVersion='0.0.0';policyDigest=$null;target='preview';stage='Prepare';outcome='blocked';findings=@(@{code='MISSING';severity='blocker';scope='platform';subject='Inputs';message='Missing input';remediation='Restore input';evidence=@()});inventory=@{wrapper=@{state='unknown';languages=@()};guides=@()}}
        Mock Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build {
            param($Method,$Endpoint,$Body)
            if($Endpoint -match '/pulls/'){return @{state='open';head=@{sha=('a'*40)}}}
            if($Method -eq 'POST'){return @{id=1}}
        }
    }
    It 'posts blocked findings without updating any existing report' {
        (Publish-GuideAssessmentComment $assessment org/repo 35 100).Outcome | Should -Be delivered
        Should -Invoke Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build -Times 1 -Exactly -ParameterFilter {$Method -eq 'POST' -and $Body.body -match 'Prepare: blocked'}
        Should -Invoke Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build -Times 0 -Exactly -ParameterFilter {$Method -in @('PATCH','DELETE','PUT')}
    }
    It 'suppresses stale source evidence before writing' {
        Mock Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build { @{state='open';head=@{sha=('b'*40)}} }
        (Publish-GuideAssessmentComment $assessment org/repo 35 100).Code | Should -Be REPORT_SUPERSEDED
        Should -Invoke Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build -Times 0 -Exactly -ParameterFilter {$Method -eq 'POST'}
    }
    It 'rechecks the head after listing comments' {
        Mock Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build {
            param($Method,$Endpoint)
            if($Endpoint -match '/pulls/'){return @{state='open';head=@{sha=('a'*40)}}}
            Mock Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build { @{state='closed';head=@{sha=('a'*40)}} }
        }
        (Publish-GuideAssessmentComment $assessment org/repo 35 100).Code | Should -Be REPORT_SUPERSEDED
    }
    It 'supports a read-only rehearsal' {
        (Publish-GuideAssessmentComment $assessment org/repo 35 100 -WhatIf).Code | Should -Be REPORT_NOT_POSTED
        Should -Invoke Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build -Times 0 -Exactly -ParameterFilter {$Method -eq 'POST'}
    }
    It 'reports API failure without changing assessment outcome' {
        Mock Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build { throw 'Service unavailable' }
        (Publish-GuideAssessmentComment $assessment org/repo 35 100).Code | Should -Be REPORT_DELIVERY_FAILED
        $assessment.outcome | Should -Be blocked
    }
    It 'recognizes its previously delivered exact report' {
        $marker="<!-- openguide-assessment:100/1/preview/Prepare/$('a'*40) -->"
        $body=$marker+"`nAssessment for this commit and run only. [Workflow evidence](https://github.com/org/repo/actions/runs/100).`n`n"+(ConvertTo-GuideAssessmentMarkdown $assessment)
        Mock Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build { @{user=@{login='github-actions[bot]'};body=$body} } -ParameterFilter {$Endpoint -match '/comments'}
        (Publish-GuideAssessmentComment $assessment org/repo 35 100).Code | Should -Be REPORT_ALREADY_DELIVERED
        Should -Invoke Invoke-GuideGitHubRequest -ModuleName OpenGuidePlatform.PowerShell.Build -Times 0 -Exactly -ParameterFilter {$Method -eq 'POST'}
    }
}