BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1') -Force
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1') -Force
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
    It 'omits healthy web and PDF-only translations from guide fixes but retains their JSON inventory' {
        $edition.translations+=@{language='fa';intent='pdf-only';downloads=@(@{path='guide.fa.pdf';handling='supplied'})}
        [IO.File]::WriteAllText("$directory/guide.fa.pdf",'supplied PDF fixture')
        $result=Get-GuideAssessment $workspace $policy @('en','fa') @{} ('a'*40) '0.0.0'
        @($result.findings|Where-Object scope -in @('translation','download')).Count|Should -Be 0
        $result.inventory.guides[0].editions[0].translations.Count|Should -Be 2
        $markdown=ConvertTo-GuideAssessmentMarkdown $result
        $markdown|Should -Match 'No guide fixes identified'
        $markdown|Should -Not -Match '\| Body \||pdf-only|guide.fa.pdf'
    }
    It 'reports a missing PDF as a PDF problem, without asking for a web body' {
        $edition.translations+=@{language='fa';intent='pdf-only';downloads=@(@{path='guide.fa.pdf';handling='supplied'})}
        $result=Get-GuideAssessment $workspace $policy @('en','fa') @{} ('a'*40) '0.0.0'
        $markdown=ConvertTo-GuideAssessmentMarkdown $result
        $markdown|Should -Match 'PDF-only translation has no available PDF'
        $markdown|Should -Match 'A web body is not required'
        $markdown|Should -Match 'Restore the declared PDF'
        $markdown|Should -Not -Match 'body: missing'
    }
    It 'includes actionable warnings and blockers once without listing unaffected translations' {
        $result=Get-GuideAssessment $workspace $policy @('en') @{} ('a'*40) '0.0.0'
        $result.findings=@(
            @{severity='warning';scope='download';subject='guide/edition/fa/generated.pdf';code='DOWNLOAD_MISSING';message='Missing generated PDF';remediation='Generate the PDF'},
            @{severity='blocker';scope='edition';subject='guide/broken';code='EDITION_ASSESSMENT_FAILED';message='Unreadable edition';remediation='Repair the document'}
        )
        $markdown=ConvertTo-GuideAssessmentMarkdown $result
        ([regex]::Matches($markdown,'DOWNLOAD_MISSING')).Count|Should -Be 1
        $markdown|Should -Match 'Generate the PDF'
        $markdown|Should -Match 'Repair the document'
        $markdown|Should -Not -Match '\| web \||\| populated \|'
    }
    It 'keeps informational observations in JSON without presenting them as fixes' {
        $result=Get-GuideAssessment $workspace $policy @('en') @{} ('a'*40) '0.0.0'
        $result.findings=@(
            @{severity='info';scope='platform';subject='module';code='MODULE_CURRENT';message='Current';remediation='Review the module'},
            @{severity='info';scope='wrapper';subject='site';code='WRAPPER_BUILD_EVIDENCE_PENDING';message='Pending';remediation='Run Build'},
            @{severity='warning';scope='platform';subject='module';code='MODULE_FRESHNESS_UNAVAILABLE';message='Lookup failed';remediation='Check connectivity'}
        )
        $markdown=ConvertTo-GuideAssessmentMarkdown $result
        $markdown|Should -Not -Match 'MODULE_CURRENT|WRAPPER_BUILD_EVIDENCE_PENDING|Review the module|readiness: unknown'
        $markdown|Should -Match 'Hugo module: current'
        $markdown|Should -Match 'MODULE_FRESHNESS_UNAVAILABLE'
        $markdown|Should -Match 'Check connectivity'
        $result.findings.Count|Should -Be 3
    }
    It 'blocks final input drift before publishing a report and retains independent findings' {
        $policy.wrapper.requiredFiles=@('site/missing.txt')
        $policy.wrapper.requiredI18nKeys=@()
        $policyPath=Join-Path $workspace 'policy.json'
        [IO.File]::WriteAllText($policyPath,($policy|ConvertTo-Json -Depth 50))
        [IO.File]::WriteAllText((Join-Path $workspace 'production.json'),'{}')
        [IO.File]::WriteAllText((Join-Path $workspace 'overlay.json'),'{}')
        $inputArguments=@{WorkspaceRoot=$workspace;Policy=$policy;PolicyPath='policy.json';PlatformRoot=$root;OverlayPath=(Join-Path $workspace 'overlay.json');Version='0.0.0';Target='preview'}
        $expected=Get-GuidePreparedInputs @inputArguments
        [IO.File]::WriteAllText((Join-Path $directory 'index.md'),"---`ntitle: Changed`n---`nChanged while preparing")
        Mock Get-GuideModuleFreshness -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { [pscustomobject]@{Code='MODULE_CURRENT';Severity='info';Module='fixture';Installed='v1';Latest='v1';Message='Fixture'} }
        $entry=Join-Path $root 'system/OpenGuidePlatform.PowerShell.GuideSiteBuild/GuideSiteBuild/Prepare-GuideSite.ps1'
        { & $entry -WorkspaceRoot $workspace -PolicyPath $policyPath -Languages @('en') -EffectiveProductionPath (Join-Path $workspace 'production.json') -SourceCommit ('a'*40) -OutputPath '.processing/drift' -Target preview -ExpectedInputs $expected -InputArguments $inputArguments -SummaryPath (Join-Path $workspace 'summary.md') } | Should -Throw '*Prepare blocked*'
        $record=Get-Content "$workspace/.processing/drift/assessment.json" -Raw|ConvertFrom-Json
        $record.outcome | Should -Be blocked
        $record.findings.code | Should -Contain WRAPPER_FILE_MISSING
        $record.findings.code | Should -Contain PREPARE_INPUTS_UNVERIFIED
        Get-Content "$workspace/summary.md" -Raw | Should -Not -Match 'Prepare: pass'
        Get-Content "$workspace/.processing/drift/assessment.md" -Raw | Should -Match 'Stop concurrent edits'
    }
    It 'blocks an enabled excluded default language only in its declared environment' {
        $policy.publication.environments=@(@{name='preview';excludedLanguages=@('en');excludedGuides=@()})
        $result=Get-GuideAssessment $workspace $policy @('en') @{} ('a'*40) '0.0.0' -Target preview
        $result.outcome | Should -Be fail
        $result.findings.code | Should -Contain ENVIRONMENT_LANGUAGE_ENABLED
        $other=Get-GuideAssessment $workspace $policy @('en') @{} ('a'*40) '0.0.0' -Target production
        $other.findings.code | Should -Not -Contain ENVIRONMENT_LANGUAGE_ENABLED
        $disabled=Get-GuideAssessment $workspace $policy @('fa') @{} ('a'*40) '0.0.0' -Target preview
        $disabled.findings.code | Should -Not -Contain ENVIRONMENT_LANGUAGE_ENABLED
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
        $entry=Join-Path $root 'system/OpenGuidePlatform.PowerShell.GuideSiteBuild/GuideSiteBuild/Prepare-GuideSite.ps1'
        { & $entry -WorkspaceRoot $workspace -PolicyPath (Join-Path $workspace 'missing-policy.json') -SourceCommit ('a'*40) -OutputPath '.processing/blocked-input' -SummaryPath (Join-Path $workspace 'fixture-summary.md') } | Should -Throw '*Prepare blocked*'
        $report=Get-Content (Join-Path $workspace '.processing/blocked-input/assessment.json') -Raw|ConvertFrom-Json -AsHashtable
        $report.policyDigest | Should -BeNullOrEmpty
        $report.findings[0].code | Should -Be PREPARE_INPUT_UNAVAILABLE
        $report.outcome='pass';$report.findings=@()
        Test-Json -Json ($report|ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/Contracts/assessment.schema.json') -ErrorAction SilentlyContinue | Should -BeFalse
    }}