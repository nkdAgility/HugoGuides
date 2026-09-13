BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1') -Force
}
Describe 'Wrapper readiness observations' {
    BeforeEach {
        $policy=Get-Content -Raw (Join-Path $root 'tests/Contracts/fixtures/single-guide.site-policy.json')|ConvertFrom-Json -AsHashtable
        $policy.wrapper.requiredI18nKeys=@('title','download')
        $policy.wrapper.requiredFiles=@('site/static/logo.svg')
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory((Join-Path $workspace 'site/i18n'))|Out-Null
        $catalog=Join-Path $workspace 'site/i18n/fa.yaml'
        [IO.File]::WriteAllText($catalog,"- id: title`n  translation: عنوان`n- id: download`n  translation: ''`n")
    }
    It 'reports populated and empty Persian keys without changing the catalogue' {
        $hash=(Get-FileHash $catalog).Hash
        $result=Get-GuideWrapperStatus $workspace $policy @('fa')
        $result.Languages[0].Keys[0].State | Should -Be present
        $result.Languages[0].Keys[1].State | Should -Be empty
        $result.Files[0].State | Should -Be missing
        (Get-FileHash $catalog).Hash | Should -Be $hash
        $result.TranslationQualityAssessed | Should -BeFalse
    }
    It 'does not pass routes or integration points without observations' {
        $result=Get-GuideWrapperStatus $workspace $policy @('fa')
        @($result.Routes | Where-Object State -ne unknown).Count | Should -Be 0
        $result.IntegrationPoints[0].State | Should -Be unknown
        $observed=Get-GuideWrapperStatus $workspace $policy @('fa') -ObservedRoutes @('/') -ObservedIntegrationPoints @()
        $observed.Routes[0].State | Should -Be present
        $observed.Routes[1].State | Should -Be missing
        $observed.IntegrationPoints[0].State | Should -Be missing
    }
    It 'collects independent missing language and invalid catalogue findings' {
        [IO.File]::WriteAllText($catalog,"- id: title`n  translation: one`n- id: title`n  translation: two`n")
        $result=Get-GuideWrapperStatus $workspace $policy @('fa','es-419')
        $result.Languages[0].Catalogue | Should -Be invalid
        $result.Languages[1].Catalogue | Should -Be missing
    }
    It 'accepts mapping catalogues and plural values while reporting absent keys' {
        [IO.File]::WriteAllText($catalog,"title:`n  other: عنوان`n")
        $result=Get-GuideWrapperStatus $workspace $policy @('fa')
        $result.Languages[0].Keys[0].State | Should -Be present
        $result.Languages[0].Keys[1].State | Should -Be missing
    }
    It 'rejects ambiguous YAML extensions and unsafe language paths' {
        [IO.File]::WriteAllText((Join-Path $workspace 'site/i18n/fa.yml'),'title: Example')
        (Get-GuideWrapperStatus $workspace $policy @('fa')).Languages[0].Catalogue | Should -Be ambiguous
        { Get-GuideWrapperStatus $workspace $policy @('../outside') } | Should -Throw '*Invalid wrapper language*'
    }
}