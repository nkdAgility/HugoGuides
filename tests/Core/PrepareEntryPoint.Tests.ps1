BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
Describe 'Root guide-site Prepare failure reports' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($workspace)|Out-Null
        & git -C $workspace init --quiet
        & git -C $workspace -c user.name=Fixture -c user.email=fixture@example.test commit --allow-empty -m Fixture --quiet
        if($LASTEXITCODE -ne 0){throw 'Could not create isolated source identity'}
        $previousSummary=$env:GITHUB_STEP_SUMMARY
        $env:GITHUB_STEP_SUMMARY=Join-Path $workspace 'summary.md'
    }
    AfterEach { $env:GITHUB_STEP_SUMMARY=$previousSummary }
    It 'reports a missing policy through the public root entry point' {
        { & "$root/build.ps1" -Product GuideSite -Stage Prepare -WorkspaceRoot $workspace -PolicyPath missing.json -OutputPath .processing/check } | Should -Throw '*Prepare blocked*'
        $assessment=Get-Content "$workspace/.processing/check/prepare/assessment.json" -Raw|ConvertFrom-Json
        $assessment.outcome | Should -Be blocked
        $assessment.findings.code | Should -Contain PREPARE_INPUT_UNAVAILABLE
        $assessment.inventory.wrapper.state | Should -Be unknown
        Get-Content "$workspace/summary.md" -Raw | Should -Match 'PREPARE_INPUT_UNAVAILABLE'
        Test-Path "$workspace/.processing/check/prepare/inputs.json" | Should -BeFalse
    }
    It 'reports invalid build configuration before invoking Hugo' {
        Copy-Item "$root/tests/Contracts/fixtures/single-guide.site-policy.json" "$workspace/policy.json"
        { & "$root/build.ps1" -Product GuideSite -Stage Prepare -WorkspaceRoot $workspace -PolicyPath policy.json -BaseUrl ftp://example.test/ -OutputPath .processing/check } | Should -Throw '*Prepare blocked*'
        $assessment=Get-Content "$workspace/.processing/check/prepare/assessment.json" -Raw|ConvertFrom-Json
        $assessment.outcome | Should -Be blocked
        $assessment.findings.message | Should -Match 'BaseUrl'
        Get-Content "$workspace/.processing/check/prepare/assessment.md" -Raw | Should -Match 'Correct the policy/configuration'
    }
}