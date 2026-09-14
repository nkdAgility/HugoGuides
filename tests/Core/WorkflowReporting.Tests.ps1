BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module powershell-yaml
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
    $workflow=ConvertFrom-Yaml (Get-Content "$root/.github/workflows/guide-site-build.yaml" -Raw)
}
Describe 'Prepare reporting through the released PowerShell module' {
    BeforeEach {
        $assessmentRoot=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item $assessmentRoot -ItemType Directory | Out-Null
        $sha='a'*40
        @{schemaVersion=1;sourceCommit=$sha;target='preview';stage='Prepare';outcome='pass'}|ConvertTo-Json|Set-Content "$assessmentRoot/assessment.json"
        [IO.File]::WriteAllText("$assessmentRoot/assessment.md", "## Prepare: pass`n`n"+'$(throw "Report text is data")')
        $arguments=@{AssessmentRoot=$assessmentRoot;Repository='org/repo';PullRequest=35;RunId=100;SourceCommit=$sha;Target='preview';PrepareResult='success'}
        $global:OgpReportTest=@{Gets=0;StaleAt=0;Comments=@();Writes=@();Failure=$false}
        Mock Invoke-GuideGitHubApi -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild {
            param($Path,$Method='GET',$Body)
            $state=$global:OgpReportTest
            if($Method -in @('POST','PATCH')){
                if($state.Failure){throw 'API unavailable'}
                $state.Writes+=@{Path=$Path;Method=$Method;Body=$Body.body};return
            }
            if($Path -match '/pulls/'){
                $state.Gets++
                return @{state='open';head=@{sha=if($state.StaleAt -and $state.Gets -ge $state.StaleAt){'b'*40}else{'a'*40}}}
            }
            return $state.Comments
        }
    }
    AfterAll { Remove-Variable OgpReportTest -Scope Global -ErrorAction SilentlyContinue }
    It 'restores platform code independently and consumes only the assessment artifact' {
        $job=$workflow.jobs['prepare-report']
        $job.permissions['pull-requests']|Should -Be write
        $workflow.permissions['pull-requests']|Should -BeNullOrEmpty
        $checkouts=@($job.steps|Where-Object { $_['uses'] -like 'actions/checkout@*' })
        $checkouts.Count|Should -Be 1
        $checkouts[0].with.repository|Should -Be 'nkdAgility/OpenGuidePlatform'
        $checkouts[0].with.ref|Should -Be '${{ needs.prepare.outputs.platform-source }}'
        $checkouts[0].with['persist-credentials']|Should -BeFalse
        ($job.steps|Where-Object { $_['uses'] -like 'actions/download-artifact@*' }).with.name|Should -Be 'GuideSite-Assessment'
        (($job.steps|ForEach-Object { $_['run'] }) -join "`n")|Should -Match 'Restore-OpenGuidePlatform.ps1 -FromWorkflow'
        (($job.steps|ForEach-Object { $_['run'] }) -join "`n")|Should -Match 'Invoke-GuideSiteGitHubAction.ps1 -Operation PublishPrepare'
    }
    It 'delivers current evidence without executing report text' {
        Publish-GuidePrepareAssessment @arguments|Should -Be REPORT_DELIVERED
        $global:OgpReportTest.Writes.Count|Should -Be 1
        $global:OgpReportTest.Writes[0].Body|Should -Match 'Report text is data'
    }
    It 'reports blocked findings even when Prepare failed' {
        $a=Get-Content "$assessmentRoot/assessment.json" -Raw|ConvertFrom-Json
        $a.outcome='blocked';$a|ConvertTo-Json|Set-Content "$assessmentRoot/assessment.json"
        [IO.File]::WriteAllText("$assessmentRoot/assessment.md","## Prepare: blocked`n")
        $arguments.PrepareResult='failure'
        Publish-GuidePrepareAssessment @arguments|Should -Be REPORT_DELIVERED
        $global:OgpReportTest.Writes[0].Body|Should -Match 'did not complete successfully'
    }
    It 'does not publish stale evidence at either identity check' -ForEach @(1,2) {
        $global:OgpReportTest.StaleAt=$_
        Publish-GuidePrepareAssessment @arguments|Should -Be REPORT_SUPERSEDED
        $global:OgpReportTest.Writes.Count|Should -Be 0
    }
    It 'avoids duplicates and updates the existing bot comment' {
        $null=Publish-GuidePrepareAssessment @arguments
        $body=$global:OgpReportTest.Writes[0].Body
        $global:OgpReportTest.Comments=@(@{id=42;user=@{login='github-actions[bot]'};body=$body})
        $global:OgpReportTest.Writes=@()
        Publish-GuidePrepareAssessment @arguments|Should -Be REPORT_ALREADY_DELIVERED
        $global:OgpReportTest.Writes.Count|Should -Be 0
        $global:OgpReportTest.Comments[0].body+=' old'
        Publish-GuidePrepareAssessment @arguments|Should -Be REPORT_DELIVERED
        $global:OgpReportTest.Writes[0].Method|Should -Be PATCH
        $global:OgpReportTest.Writes[0].Path|Should -Be 'repos/org/repo/issues/comments/42'
    }
    It 'does not overwrite human comments or a different target' -ForEach @('human','production') {
        $null=Publish-GuidePrepareAssessment @arguments
        $body=$global:OgpReportTest.Writes[0].Body
        $global:OgpReportTest.Comments=@(@{id=42;user=@{login=if($_ -eq 'human'){'maintainer'}else{'github-actions[bot]'}};body=if($_ -eq 'human'){$body}else{$body.Replace('preview/Prepare','production/Prepare')}})
        $global:OgpReportTest.Writes=@()
        Publish-GuidePrepareAssessment @arguments|Should -Be REPORT_DELIVERED
        $global:OgpReportTest.Writes[0].Method|Should -Be POST
    }
    It 'distinguishes delivery failure from assessment outcome' {
        $global:OgpReportTest.Failure=$true
        {Publish-GuidePrepareAssessment @arguments}|Should -Throw '*REPORT_DELIVERY_FAILED*Assessment outcome was not changed*'
    }
    It 'rejects missing, mismatched or oversized evidence' -ForEach @('missing','identity','oversized') {
        switch($_){
            missing { Remove-Item "$assessmentRoot/assessment.json" }
            identity { $arguments.SourceCommit='b'*40 }
            oversized { [IO.File]::WriteAllText("$assessmentRoot/assessment.md","## Prepare: pass`n"+('x'*65000)) }
        }
        {Publish-GuidePrepareAssessment @arguments}|Should -Throw '*REPORT_DELIVERY_FAILED*'
        $global:OgpReportTest.Writes.Count|Should -Be 0
    }
}
