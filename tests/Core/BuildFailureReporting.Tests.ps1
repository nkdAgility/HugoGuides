BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1"
}
Describe 'Plain-language build failure reporting' {
    It 'preserves the authored cause and repair in local output, Actions annotations and summary files' {
        try{throw (New-PlatformBuildFailure -Why 'The workflow check read actions.lock as a workflow. Lockfiles have no jobs.' -HowToFix 'Scan only .yml and .yaml files; exclude actions.lock.')}catch{$record=$_}
        $result=[pscustomobject]@{Result='Failed';PassedCount=0;FailedCount=1;SkippedCount=0;TotalCount=1;Failed=@([pscustomobject]@{ExpandedPath='Workflow validation';ErrorRecord=@($record)})}
        $output=Join-Path $TestDrive 'report';$summary=Join-Path $TestDrive 'actions.md'
        $console=Write-PlatformTestSummary -Result $result -OutputPath $output -SummaryPath $summary -Reporter GitHub 6>&1|Out-String
        $console|Should -Match '::error title=Platform build failed::Why: The workflow check read actions.lock'
        $console|Should -Match 'How to fix: Scan only'
        $text=Get-Content "$output/summary.md" -Raw
        $text|Should -Match '\*\*Why:\*\* The workflow check read actions.lock'
        $text|Should -Match '\*\*How to fix:\*\* Scan only'
        (Get-Content $summary -Raw).Trim()|Should -Be $text.Trim()
        (Get-Content "$output/findings.json" -Raw|ConvertFrom-Json)[0].howToFix|Should -Be 'Scan only .yml and .yaml files; exclude actions.lock.'
    }
    It 'does not invent a repair for an unclassified exception' {
        try{throw 'Unexpected test engine failure'}catch{$record=$_}
        $result=[pscustomobject]@{Result='Failed';PassedCount=0;FailedCount=1;SkippedCount=0;TotalCount=1;Failed=@([pscustomobject]@{ExpandedPath='Example';ErrorRecord=@($record)})}
        $output=Join-Path $TestDrive 'unknown'
        Write-PlatformTestSummary -Result $result -OutputPath $output -SummaryPath '' -Reporter Local
        Get-Content "$output/summary.md" -Raw|Should -Match 'automatic repair is not known'
    }
}
