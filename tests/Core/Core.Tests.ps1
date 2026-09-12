BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1') -Force
    function New-TestPolicy {
        $p=Get-Content -Raw (Join-Path $root 'tests/Contracts/fixtures/single-guide.site-policy.json') | ConvertFrom-Json -AsHashtable
        $p.siteId='fixture';$p.protectedPaths=@();$p.guides[0].id='guide-a';$p.guides[0].contentRoot='site/content/guide-a';$p.guides[0].protectSource=$false
        $p.guides[0].editions[0].id='2026.1';$p.guides[0].editions[0].path='2026.1';$p.guides[0].editions[0].translations[0].downloads=@()
        return $p
    }
}
Describe 'Language and readiness decisions' {
    It 'uses the supplied default language for index.md' { Get-GuideLanguage index.md fr | Should -Be 'fr' }
    It 'supports numeric regions and script subtags' {
        Get-GuideLanguage index.es-419.md en | Should -Be 'es-419'
        Get-GuideLanguage index.zh-Hant.md en | Should -Be 'zh-Hant'
    }
    It 'rejects unexpected filenames' { { Get-GuideLanguage '../index.fa.md' en } | Should -Throw }
    It 'accepts a supplied PDF with no web body' { (Get-GuideTranslationState pdf-only missing -HasDownload $true).Ready | Should -BeTrue }
    It 'does not equate an empty web translation with ready' { (Get-GuideTranslationState web empty).State | Should -Be 'unknown' }
    It 'retains populated scaffolds for an intent review' { (Get-GuideTranslationState scaffold populated).FindingCode | Should -Be 'POPULATED_SCAFFOLD_REVIEW_INTENT' }
    It 'does not mark a missing fallback ready' { (Get-GuideTranslationState fallback empty).Ready | Should -BeFalse }
    It 'accepts a available source-language fallback' { (Get-GuideTranslationState fallback empty -FallbackAvailable $true).State | Should -Be 'fallback' }
    It 'hashes normalized email without returning the email itself' {
        $a=Get-GuideGravatar ' PERSON@example.com ';$b=Get-GuideGravatar 'person@example.com'
        $a.Hash | Should -Be $b.Hash
        $a.PSObject.Properties.Name | Should -Not -Contain 'Email'
    }
}
Describe 'Policy semantics and permanent exclusions' {
    BeforeEach { $policy=New-TestPolicy }
    It 'rejects duplicate guide identities' {
        $policy.guides+=($policy.guides[0]|ConvertTo-Json -Depth 20|ConvertFrom-Json -AsHashtable)
        @(Get-GuidePolicyFinding $policy).Code | Should -Contain 'DUPLICATE_GUIDE'
    }
    It 'detects fallback cycles' {
        $policy.guides[0].editions[0].translations=@(@{language='fr';intent='fallback';fallbackLanguage='en';downloads=@()},@{language='en';intent='fallback';fallbackLanguage='fr';downloads=@()})
        @(Get-GuidePolicyFinding $policy).Code | Should -Contain 'FALLBACK_CYCLE'
    }
    It 'detects missing extension parents' {
        $policy.guides[0].relationship=@{kind='extension';parentGuideId='missing'}
        @(Get-GuidePolicyFinding $policy).Code | Should -Contain 'UNKNOWN_PARENT_GUIDE'
    }
    It 'rejects enabled production language regardless of requested preview work' {
        $policy.publication.permanentExclusions=@(@{environment='production';subject='language';id='min';reason='Never publish'})
        @(Test-GuidePublicationPolicy $policy @{languages=@{min=@{disabled=$false}}}).Code | Should -Contain 'PERMANENT_LANGUAGE_ENABLED'
        @(Test-GuidePublicationPolicy $policy @{languages=@{min=@{disabled=$true}}}).Count | Should -Be 0
        @(Test-GuidePublicationPolicy $policy @{languages=@{}}).Code | Should -Contain 'PRODUCTION_LANGUAGE_STATE_UNKNOWN'
    }
    It 'does not assume guide exclusions without effective evidence' {
        $policy.publication.permanentExclusions=@(@{environment='production';subject='guide';id='extension';reason='Excluded'})
        @(Test-GuidePublicationPolicy $policy @{languages=@{}}).Code | Should -Contain 'PUBLICATION_EVIDENCE_REQUIRED'
    }
}
Describe 'Filesystem publishing operations' {
    BeforeEach {
        $policy=New-TestPolicy
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $edition=Join-Path $workspace 'site/content/guide-a/2026.1'
        [IO.Directory]::CreateDirectory($edition)|Out-Null
        $original="---`ntitle: Guide`nversion: 2026.1`nlang: en`naliases:`n  - /guide-a/latest`n---`nKeep this exact body.`n"
        [IO.File]::WriteAllText((Join-Path $edition 'index.md'),$original)
        [IO.File]::WriteAllText((Join-Path $workspace 'site/hugo.production.yaml'),"languages:`n  fa:`n    disabled: true`n  es-419:`n    disabled: true`n")
    }
    It 'creates only an empty guide body and preserves aliases/source/config' {
        $configPath=Join-Path $workspace 'site/hugo.production.yaml';$hash=(Get-FileHash $configPath).Hash
        (New-GuideTranslationScaffold $workspace $policy guide-a 2026.1 fa).Status | Should -Be 'created'
        $raw=[IO.File]::ReadAllText((Join-Path $edition 'index.fa.md'))
        $raw | Should -Match '(?m)^  - /guide-a/latest$'
        $raw | Should -Not -Match '(?m)^lang:'
        $raw | Should -Not -Match 'Keep this exact body'
        [IO.File]::ReadAllText((Join-Path $edition 'index.md')) | Should -BeExactly $original
        (Get-FileHash $configPath).Hash | Should -Be $hash
    }
    It 'preserves populated translations during reconciliation' {
        $target=Join-Path $edition 'index.fa.md';[IO.File]::WriteAllText($target,"---`ntitle: Persian`n---`nمتن فارسی`n")
        $hash=(Get-FileHash $target).Hash
        (New-GuideTranslationScaffold $workspace $policy guide-a 2026.1 fa).Status | Should -Be 'preserved'
        (Get-FileHash $target).Hash | Should -Be $hash
    }
    It 'requires production to be explicitly disabled for a new language' {
        { New-GuideTranslationScaffold $workspace $policy guide-a 2026.1 ja } | Should -Throw '*disabled*'
        Test-Path (Join-Path $edition 'index.ja.md') | Should -BeFalse
    }
    It 'refuses protected guide scaffolding' {
        $policy.guides[0].protectSource=$true
        { New-GuideTranslationScaffold $workspace $policy guide-a 2026.1 fa } | Should -Throw '*PROTECTED_RESOURCE*'
    }
    It 'honors WhatIf' {
        New-GuideTranslationScaffold $workspace $policy guide-a 2026.1 fa -WhatIf
        Test-Path (Join-Path $edition 'index.fa.md') | Should -BeFalse
    }
    It 'rejects traversal before reading content' {
        $policy.guides[0].contentRoot='../outside'
        { Get-GuideInventory $workspace $policy } | Should -Throw '*Unsafe*'
    }
    It 'rejects directory symlinks rather than following them' {
        $outside=Join-Path $TestDrive 'outside';[IO.Directory]::CreateDirectory($outside)|Out-Null
        $link=Join-Path $workspace 'linked'
        try { $null=New-Item -ItemType SymbolicLink -Path $link -Target $outside -ErrorAction Stop } catch { Set-ItResult -Skipped -Because 'Host does not grant symlink creation.';return }
        $policy.guides[0].contentRoot='linked'
        { Get-GuideInventory $workspace $policy } | Should -Throw '*Linked*'
    }
    It 'observes intent and supplied downloads without generating PDFs' {
        $pdfDir=Join-Path $edition 'pdf';[IO.Directory]::CreateDirectory($pdfDir)|Out-Null;[IO.File]::WriteAllText((Join-Path $pdfDir 'fa.pdf'),'%PDF-fixture')
        $policy.guides[0].editions[0].translations+=@{language='fa';intent='pdf-only';downloads=@(@{path='pdf/fa.pdf';handling='supplied'})}
        $inventory=Get-GuideInventory $workspace $policy
        $inventory.Guides[0].Editions[0].Translations[1].State | Should -Be 'pdf-only'
        $inventory.Guides[0].Editions[0].Translations[0].DeprecatedLang | Should -BeTrue
    }
    It 'snapshots a draft edition without changing the source or live aliases' {
        $result=New-GuideEdition $workspace $policy guide-a 2026.1 2025.12 2025.12
        $result.Status | Should -Be 'created-draft'
        $new=[IO.File]::ReadAllText((Join-Path $workspace 'site/content/guide-a/2025.12/index.md'))
        $new | Should -Match '(?m)^draft: true'
        $new | Should -Not -Match '(?m)^aliases:'
        $new | Should -Match 'Keep this exact body\.'
        [IO.File]::ReadAllText((Join-Path $edition 'index.md')) | Should -BeExactly $original
        { New-GuideEdition $workspace $policy guide-a 2026.1 2025.12 2025.12 } | Should -Throw '*already exists*'
    }
    It 'refuses protected edition creation' {
        $policy.guides[0].protectSource=$true
        { New-GuideEdition $workspace $policy guide-a 2026.1 2025.12 2025.12 } | Should -Throw '*PROTECTED_RESOURCE*'
    }
    It 'creates contributor data at the consumer root and refuses replacement' {
        $entries=@(@{name='Example Person';role='contributor';contributions=@('2026.1')})
        (New-GuideContributions $workspace $policy guide-a $entries).Status | Should -Be 'created'
        Test-Path (Join-Path $workspace 'site/data/contributions/guide-a.yml') | Should -BeTrue
        { New-GuideContributions $workspace $policy guide-a $entries } | Should -Throw '*exists*'
    }
    It 'preserves declared PDF names and passes Persian explicitly' {
        [IO.File]::WriteAllText((Join-Path $edition 'index.fa.md'),"---`ntitle: Persian`n---`nمتن فارسی`n")
        $policy.guides[0].editions[0].translations+=@{language='fa';intent='web';downloads=@(@{path='pdf/custom.v2026.1.fa.pdf';handling='generated'})}
        $plan=Get-GuidePdfPlan $workspace $policy guide-a 2026.1 fa 'pdf/custom.v2026.1.fa.pdf'
        $plan.Language | Should -Be 'fa';$plan.Arguments | Should -Contain 'lang=fa'
        $plan.Output | Should -Match 'custom\.v2026\.1\.fa\.pdf$'
        $plan.Fingerprints.Count | Should -Be 1
    }
    It 'refuses supplied or protected PDF regeneration' {
        $policy.guides[0].editions[0].translations[0].downloads=@(@{path='pdf/existing.pdf';handling='protected'})
        { Get-GuidePdfPlan $workspace $policy guide-a 2026.1 en 'pdf/existing.pdf' } | Should -Throw '*supplied and protected*'
    }
    It 'propagates a Pandoc failure without publishing output' {
        $policy.guides[0].editions[0].translations[0].downloads=@(@{path='pdf/generated.pdf';handling='generated'})
        Mock Get-GuidePdfToolchain -ModuleName OpenGuidePlatform.PowerShell.Core { @([pscustomobject]@{Tool='pandoc';Available=$true},[pscustomobject]@{Tool='xelatex';Available=$true}) }
        Mock Get-Command -ModuleName OpenGuidePlatform.PowerShell.Core -ParameterFilter { $Name -eq 'fc-list' } { $null }
        Mock Invoke-GuidePandoc -ModuleName OpenGuidePlatform.PowerShell.Core { 42 }
        { New-GuidePdf $workspace $policy guide-a 2026.1 en 'pdf/generated.pdf' } | Should -Throw '*exit code 42*'
        Test-Path (Join-Path $edition 'pdf/generated.pdf') | Should -BeFalse
    }
    It 'refuses replacement of an existing generated PDF' {
        $policy.guides[0].editions[0].translations[0].downloads=@(@{path='pdf/generated.pdf';handling='generated'})
        $target=Join-Path $edition 'pdf/generated.pdf';[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null;[IO.File]::WriteAllText($target,'%PDF-original')
        $hash=(Get-FileHash $target).Hash
        { New-GuidePdf $workspace $policy guide-a 2026.1 en 'pdf/generated.pdf' } | Should -Throw '*already exists*'
        (Get-FileHash $target).Hash | Should -Be $hash
    }
}
