BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1') -Force
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
}
Describe 'Shared Prepare assessment and reports' {
    BeforeEach {
        $policy=Get-Content -Raw (Join-Path $root 'tests/Contracts/fixtures/single-guide.site-policy.json')|ConvertFrom-Json -AsHashtable
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $guide=$policy.guides[0];$edition=$guide.editions[0]
        $directory=Join-Path $workspace "$($guide.contentRoot)/$($edition.path)"
        [IO.Directory]::CreateDirectory($directory)|Out-Null
        [IO.File]::WriteAllText((Join-Path $directory 'index.md'),"---`ntitle: Guide`n---`nBody")
        $edition.translations[0].downloads=@()
    }
    It 'creates schema-valid evidence with runtime checks explicitly pending' {
        $result=Get-GuideAssessment $workspace $policy @('en') @{} ('a'*40) '0.0.0'
        $json=$result|ConvertTo-Json -Depth 100
        Test-Json -Json $json -SchemaFile (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/Contracts/assessment.schema.json') | Should -BeTrue
        $result.outcome | Should -Be pass
        $result.inventory.wrapper.state | Should -Be unknown
        $result.findings.code | Should -Contain WRAPPER_BUILD_EVIDENCE_PENDING
        $result.inventory.guides[0].editions[0].translations[0].state | Should -Be web
    }
    It 'collects publication and wrapper failures even when edition parsing fails' {
        [IO.File]::WriteAllText((Join-Path $directory 'index.md'),'no front matter')
        $policy.wrapper.requiredFiles=@('site/static/missing.svg')
        $policy.publication.permanentExclusions=@(@{environment='production';subject='language';id='min';reason='Never production'})
        $result=Get-GuideAssessment $workspace $policy @('en') @{languages=@{min=@{disabled=$false}}} ('a'*40) '0.0.0' -Target preview
        $result.outcome | Should -Be fail
        $result.findings.code | Should -Contain PERMANENT_LANGUAGE_ENABLED
        $result.findings.code | Should -Contain WRAPPER_FILE_MISSING
        $result.findings.code | Should -Contain EDITION_ASSESSMENT_FAILED
        Test-Json -Json ($result|ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/Contracts/assessment.schema.json') | Should -BeTrue
    }
    It 'renders actionable findings and neutralizes markup, mentions and table delimiters' {
        $policy.wrapper.requiredFiles=@('site/static/missing.svg')
        $result=Get-GuideAssessment $workspace $policy @('en') @{} ('a'*40) '0.0.0'
        $result.findings[0].message='<script>bad</script> | @someone'
        $markdown=ConvertTo-GuideAssessmentMarkdown $result
        $markdown | Should -Match 'Prepare: fail'
        $markdown | Should -Match 'Restore the required wrapper file'
        $markdown | Should -Not -Match '<script>|@someone'
        $markdown | Should -Match '&#124;'
    }
    It 'writes a failed assessment before the caller handles failure and refuses overwrite' {
        $policy.wrapper.requiredFiles=@('site/missing.txt')
        $result=Get-GuideAssessment $workspace $policy @('en') @{} ('a'*40) '0.0.0'
        $report=Write-GuideAssessmentReport $result $workspace '.processing/run-1'
        $report.Outcome | Should -Be fail
        (Get-Content $report.JsonPath -Raw | ConvertFrom-Json).outcome | Should -Be fail
        Get-Content $report.MarkdownPath -Raw | Should -Match 'WRAPPER_FILE_MISSING'
        { Write-GuideAssessmentReport $result $workspace '.processing/run-1' } | Should -Throw '*already exists*'
        { Write-GuideAssessmentReport $result $workspace '../escape' } | Should -Throw '*Unsafe*'
    }
    It 'uses effective fallback consistently in Core observations and the shared Prepare report' {
        $policy.wrapper.requiredI18nKeys=@('home')
        $evidence=@([pscustomobject]@{Language='fa';Scope='hugo-effective-i18n';Keys=@([pscustomobject]@{Key='home';State='fallback';Value='Home'})})
        $wrapper=Get-GuideWrapperStatus -WorkspaceRoot $workspace -Policy $policy -Languages @('fa') -EffectiveTranslations $evidence
        $report=Get-GuideAssessment $workspace $policy @('fa') @{} ('a'*40) '0.0.0' -EffectiveTranslations $evidence
        $wrapper.Languages[0].Keys[0].State | Should -Be present
        $wrapper.Languages[0].Keys[0].Resolution | Should -Be fallback
        $report.findings.code | Should -Contain WRAPPER_TRANSLATION_FALLBACK
        $report.findings.code | Should -Not -Contain WRAPPER_TRANSLATION_MISSING
        $report.findings.code | Should -Not -Contain WRAPPER_CATALOGUE_UNAVAILABLE
        $written=Write-GuideAssessmentReport $report $workspace '.processing/skill-and-ci'
        $readBack=Get-Content $written.JsonPath -Raw|ConvertFrom-Json
        $readBack.findings.code | Should -Contain WRAPPER_TRANSLATION_FALLBACK
        $readBack.inventory.guides[0].editions[0].translations[0].state | Should -Be $report.inventory.guides[0].editions[0].translations[0].state
    }
    It 'writes a blocked report for missing policy input and rejects unknown digest on success' {
        $entry=Join-Path $root '.build/Prepare-GuideSite.ps1'
        { & $entry -WorkspaceRoot $workspace -PolicyPath (Join-Path $workspace 'missing-policy.json') -SourceCommit ('a'*40) -OutputPath '.processing/blocked-input' -SummaryPath (Join-Path $workspace 'fixture-summary.md') } | Should -Throw '*Prepare blocked*'
        $report=Get-Content (Join-Path $workspace '.processing/blocked-input/assessment.json') -Raw|ConvertFrom-Json -AsHashtable
        $report.policyDigest | Should -BeNullOrEmpty
        $report.findings[0].code | Should -Be PREPARE_INPUT_UNAVAILABLE
        $report.outcome='pass';$report.findings=@()
        Test-Json -Json ($report|ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/Contracts/assessment.schema.json') -ErrorAction SilentlyContinue | Should -BeFalse
    }}