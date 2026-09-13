BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
}
Describe 'Reviewed wrapper translations' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory("$workspace/site/content")|Out-Null
        [IO.Directory]::CreateDirectory("$workspace/site/i18n")|Out-Null
        $policy=Get-Content "$root/tests/Contracts/fixtures/single-guide.site-policy.json" -Raw|ConvertFrom-Json -AsHashtable
        [IO.File]::WriteAllText("$workspace/site/hugo.yaml","title: Bespoke`nlanguages:`n  en:`n    languageName: English`n")
        [IO.File]::WriteAllText("$workspace/site/hugo.production.yaml","title: Bespoke`nlanguages:`n  en:`n    disabled: false`n  fa:`n    disabled: true`n")
        $argsForWrapper=@{WorkspaceRoot=$workspace;Policy=$policy;Language='fa'}
        $candidate="---`ntitle: فارسی`n---`nمتن فارسی`n"
    }
    It 'creates Persian wrapper content without changing source or configuration' {
        $before=(Get-FileHash "$workspace/site/hugo.production.yaml").Hash
        Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.fa.md -CandidateContent $candidate | Select-Object -ExpandProperty Status | Should -Be created
        Get-Content "$workspace/site/content/_index.fa.md" -Raw | Should -Be $candidate
        (Get-FileHash "$workspace/site/hugo.production.yaml").Hash | Should -Be $before
    }
    It 'preserves populated content unless its exact prior bytes were reviewed' {
        [IO.File]::WriteAllText("$workspace/site/content/_index.fa.md",$candidate)
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.fa.md -CandidateContent ($candidate+'more') } | Should -Throw '*exists*'
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.fa.md -ExpectedSha256 ('0'*64) -CandidateContent ($candidate+'more') } | Should -Throw '*changed since review*'
        Get-Content "$workspace/site/content/_index.fa.md" -Raw | Should -Be $candidate
        $hash=(Get-FileHash "$workspace/site/content/_index.fa.md").Hash
        (Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.fa.md -ExpectedSha256 $hash -CandidateContent ($candidate+'more')).Status | Should -Be updated
    }
    It 'creates and reconciles catalogues with exact reviewed text' {
        $catalogue="- id: home`n  translation: خانه`n"
        Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/i18n/fa.yaml -CandidateContent $catalogue | Out-Null
        $hash=(Get-FileHash "$workspace/site/i18n/fa.yaml").Hash
        $updated=$catalogue+"- id: search`n  translation: جستجو`n"
        Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/i18n/fa.yaml -ExpectedSha256 $hash -CandidateContent $updated | Out-Null
        Get-Content "$workspace/site/i18n/fa.yaml" -Raw | Should -Be $updated
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/i18n/fa.yml -CandidateContent $catalogue } | Should -Throw '*ambiguous*'
    }
    It 'changes only the selected language in existing configuration' {
        $hash=(Get-FileHash "$workspace/site/hugo.yaml").Hash
        $config="title: Bespoke`nlanguages:`n  en:`n    languageName: English`n  fa:`n    languageName: فارسی`n"
        (Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/hugo.yaml -ExpectedSha256 $hash -CandidateContent $config).Status | Should -Be updated
        $hash=(Get-FileHash "$workspace/site/hugo.yaml").Hash
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/hugo.yaml -ExpectedSha256 $hash -CandidateContent ($config.Replace('Bespoke','Overwritten')) } | Should -Throw '*unrelated wrapper configuration*'
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/hugo.yaml -ExpectedSha256 $hash -CandidateContent ($config.Replace('English','Changed')) } | Should -Throw '*unselected languages*'
    }
    It 'refuses production enablement and requires disabled production before creating a new language' {
        $path="$workspace/site/hugo.production.yaml"
        $hash=(Get-FileHash $path).Hash
        $bad=([IO.File]::ReadAllText($path)).Replace('disabled: true','disabled: false')
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/hugo.production.yaml -ExpectedSha256 $hash -CandidateContent $bad } | Should -Throw '*production language disabled*'
        $argsForWrapper.Language='es-419'
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.es-419.md -CandidateContent $candidate } | Should -Throw '*disabled in production*'
        $config=[IO.File]::ReadAllText($path)+"  es-419:`n    disabled: true`n"
        Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/hugo.production.yaml -ExpectedSha256 $hash -CandidateContent $config | Out-Null
        (Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.es-419.md -CandidateContent $candidate).Status | Should -Be created
    }
    It 'refuses guide content, protected paths and unselected language paths' {
        $policy.guides[0].protectSource=$false;$policy.protectedPaths=@()
        $guidePath="$($policy.guides[0].contentRoot)/index.fa.md"
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath $guidePath -CandidateContent $candidate } | Should -Throw '*guide content*'
        $policy.protectedPaths=@('site/content')
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.fa.md -CandidateContent $candidate } | Should -Throw '*PROTECTED_RESOURCE*'
        $policy.protectedPaths=@()
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.ja.md -CandidateContent $candidate } | Should -Throw '*language-specific*'
    }
    It 'rejects deprecated metadata, new legacy aliases and duplicate catalogue ids' {
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.fa.md -CandidateContent "---`nlang: fa`n---`n" } | Should -Throw '*without lang*'
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.fa.md -CandidateContent "---`naliases: ['/fa/downloads/']`n---`n" } | Should -Throw '*legacy*'
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/i18n/fa.yaml -CandidateContent "- id: home`n  translation: One`n- id: home`n  translation: Two`n" } | Should -Throw '*unique*'
    }
    It 'does not write in WhatIf mode' {
        Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.fa.md -CandidateContent $candidate -WhatIf
        Test-Path "$workspace/site/content/_index.fa.md" | Should -BeFalse
    }
    It 'preserves the previous file and cleans staging after a write failure' {
        [IO.File]::WriteAllText("$workspace/site/content/_index.fa.md",$candidate)
        $hash=(Get-FileHash "$workspace/site/content/_index.fa.md").Hash
        Mock New-GuideFile { throw 'simulated write failure' } -ModuleName OpenGuidePlatform.PowerShell.Core
        { Set-GuideWrapperTranslation @argsForWrapper -RelativePath site/content/_index.fa.md -ExpectedSha256 $hash -CandidateContent ($candidate+'more') } | Should -Throw '*simulated*'
        (Get-FileHash "$workspace/site/content/_index.fa.md").Hash | Should -Be $hash
        @(Get-ChildItem "$workspace/site/content" -Filter '*wrapper-lock').Count | Should -Be 0
    }
}