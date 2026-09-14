BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
    function Write-Edition($edition,$language,$date,$alias,$draft=$false) {
        $directory=Join-Path $TestDrive "site/content/guide/$edition"
        New-Item $directory -ItemType Directory -Force|Out-Null
        $suffix=if($language -eq 'en'){''}else{".$language"}
        "---`ndate: $date`ndraft: $($draft.ToString().ToLowerInvariant())`naliases: [$alias]`n---`nGuide body"|Set-Content "$directory/index$suffix.md"
    }
}
Describe 'Latest published edition front matter alias' {
    BeforeEach {
        $policy=@{wrapper=@{sourcePath='site'};guides=@(@{id='guide';contentRoot='site/content/guide';editions=@(@{path='2025.5';sourceLanguage='en'},@{path='2026.1';sourceLanguage='en'})})}
        Write-Edition '2025.5' en '2025-05-01' ''
        Write-Edition '2026.1' en '2026-01-01' '/guide/latest'
    }
    It 'accepts the alias on only the newest published edition' {
        @(Test-GuideLatestAliases $TestDrive $policy @('en')).Count|Should -Be 0
    }
    It 'reports a missing alias with the file and repair instructions' {
        Write-Edition '2026.1' en '2026-01-01' ''
        $result=@(Test-GuideLatestAliases $TestDrive $policy @('en'))
        $result.Count|Should -Be 1
        $result[0].remediation|Should -Match '2026.1/index.md'
    }
    It 'rejects an alias owned by an older edition' {
        Write-Edition '2025.5' en '2025-05-01' '/guide/latest'
        Write-Edition '2026.1' en '2026-01-01' ''
        @(Test-GuideLatestAliases $TestDrive $policy @('en')).Count|Should -Be 1
    }
    It 'rejects duplicate ownership even when the latest edition has the alias' {
        Write-Edition '2025.5' en '2025-05-01' '/guide/latest/'
        @(Test-GuideLatestAliases $TestDrive $policy @('en')).Count|Should -Be 1
    }
    It 'rejects draft ownership and keeps the previous published edition latest' {
        Write-Edition '2026.1' en '2026-01-01' '/guide/latest' $true
        $result=@(Test-GuideLatestAliases $TestDrive $policy @('en'))
        $result[0].remediation|Should -Match '2025.5/index.md'
        Write-Edition '2026.1' en '2026-01-01' '' $true
        Write-Edition '2025.5' en '2025-05-01' '/guide/latest'
        @(Test-GuideLatestAliases $TestDrive $policy @('en')).Count|Should -Be 0
    }
    It 'excludes future publication even when preview includes future pages' {
        Write-Edition '2026.1' en '2099-01-01' '/guide/latest'
        @(Test-GuideLatestAliases $TestDrive $policy @('en')).Count|Should -Be 1
    }
    It 'requires each enabled translation to own its latest alias independently' {
        Write-Edition '2025.5' ja '2025-05-01' ''
        @(Test-GuideLatestAliases $TestDrive $policy @('en','ja')).Count|Should -Be 1
        Write-Edition '2025.5' ja '2025-05-01' '/guide/latest'
        @(Test-GuideLatestAliases $TestDrive $policy @('en','ja')).Count|Should -Be 0
    }
}
