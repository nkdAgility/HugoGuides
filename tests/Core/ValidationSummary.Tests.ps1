BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $entry="$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/GuideSiteBuild/Write-GuideSiteValidationSummary.ps1"
}
Describe 'Actionable validation summary' {
    BeforeEach {
        $output=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($output)|Out-Null
        $report=@{Outcome='pass';SourceCommit=('a'*40);Target='canary';FileCount=10;SizeBytes=100;Findings=@()}
    }
    It 'reports success without an empty findings table' {
        $report|ConvertTo-Json|Set-Content "$output/artifact-validation.json"
        $text=& $entry -OutputPath $output -SummaryPath ''
        $text|Should -Match 'Artifact checks passed'
        $text|Should -Not -Match '\| None|What to fix|not deployment or visual'
    }
    It 'retains failures and their remedies' {
        $report.Outcome='fail'
        $report.Findings=@(@{Code='DOWNLOAD_MISSING';Path='guide.pdf';Message='Restore the supplied PDF'})
        $report|ConvertTo-Json -Depth 5|Set-Content "$output/artifact-validation.json"
        $text=& $entry -OutputPath $output -SummaryPath ''
        $text|Should -Match 'DOWNLOAD_MISSING'
        $text|Should -Match 'Restore the supplied PDF'
        $text|Should -Not -Match 'Artifact checks passed'
    }
    It 'does not turn missing evidence into success' {
        $text=& $entry -OutputPath $output -SummaryPath ''
        $text|Should -Match 'Validate: blocked'
        $text|Should -Match 'Inspect the failed build'
    }
}
