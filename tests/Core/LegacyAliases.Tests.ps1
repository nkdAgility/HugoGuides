BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
}
Describe 'Frozen legacy alias compatibility' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory("$workspace/site/content")|Out-Null
        $policy=@{wrapper=@{sourcePath='site';legacyAliases=@()}}
        foreach($guide in @('one','two')){
            $source="site/content/$guide.md"
            [IO.File]::WriteAllText("$workspace/$source","---`ntitle: Example`naliases:`n  - /download/`n---`nBody")
            $policy.wrapper.legacyAliases+=@{source=$source;language='en';aliases=@('/download/');targets=@('download/index.html')}
        }
    }
    It 'preserves known declarations and permits only their exact duplicate count' {
        (Test-GuideLegacyAliases $workspace $policy).Outcome | Should -Be pass
        $counts=Get-GuideLegacyAliasTargets $policy @('en')
        $counts['download/index.html'] | Should -Be 2
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: download/index.html (2)') -AllowedLegacyDuplicates $counts).Outcome | Should -Be pass
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: download/index.html (3)') -AllowedLegacyDuplicates $counts).Outcome | Should -Be fail
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: download/index.html (2), other/index.html (2)') -AllowedLegacyDuplicates $counts).Outcome | Should -Be fail
    }
    It 'recognizes Windows separators and regional casing only for declared legacy targets' {
        foreach($entry in $policy.wrapper.legacyAliases){$entry.language='es-ES';$entry.targets=@('es-es/download/index.html')}
        $counts=Get-GuideLegacyAliasTargets $policy @('es-es')
        $counts['es-es/download/index.html'] | Should -Be 2
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: es-es\download\index.html (2)') -AllowedLegacyDuplicates $counts).Outcome | Should -Be pass
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: es-es\other\index.html (2)') -AllowedLegacyDuplicates $counts).Outcome | Should -Be fail
    }
    It 'rejects adding a legacy alias to a new language or deleting an existing declaration' {
        [IO.File]::WriteAllText("$workspace/site/content/one.fa.md","---`ntitle: Example`naliases:`n  - /download/`n---`nBody")
        (Test-GuideLegacyAliases $workspace $policy).Findings.Code | Should -Contain 'LEGACY_ALIAS_DECLARATION_CHANGED'
        [IO.File]::WriteAllText("$workspace/site/content/one.md","---`ntitle: Example`n---`nBody")
        (Test-GuideLegacyAliases $workspace $policy).Findings.Code | Should -Contain 'LEGACY_ALIAS_DECLARATION_MISSING'
    }
    It 'preserves a language-prefixed alias with the additional Hugo language directory' {
        foreach($entry in $policy.wrapper.legacyAliases){$entry.language='pl';$entry.targets=@('pl/pl/download/index.html')}
        $counts=Get-GuideLegacyAliasTargets $policy @('pl')
        $counts['pl/pl/download/index.html'] | Should -Be 2
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: pl/pl/download/index.html (2)') -AllowedLegacyDuplicates $counts).Outcome | Should -Be pass
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: pl/pl/download/index.html (3)') -AllowedLegacyDuplicates $counts).Findings.Code | Should -Contain HUGO_DUPLICATE_TARGETS
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: pl/pl/downloads/index.html (2)') -AllowedLegacyDuplicates $counts).Findings.Code | Should -Contain HUGO_DUPLICATE_TARGETS
        (Get-GuideLegacyAliasTargets $policy @('en')).Count | Should -Be 0
    }
    It 'rejects unsafe or unsupported duplicate targets even when supplied in the allowance' -ForEach @(
        @{target='../pl/download/index.html'}, @{target='pl/../download/index.html'},
        @{target='/pl/download/index.html'}, @{target='pl/pl/pl/download/index.html'},
        @{target='pl/pl/other/index.html'}, @{target='pl/%2e%2e/download/index.html'}
    ) {
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @("WARN  Duplicate target paths: $target (2)") -AllowedLegacyDuplicates @{$target=2}).Findings.Code | Should -Contain HUGO_DUPLICATE_TARGETS
    }
    It 'does not grant inactive languages or unrelated routes a duplicate exemption' {
        (Get-GuideLegacyAliasTargets $policy @('ja')).Count | Should -Be 0
        {Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: other/index.html (2)') -AllowedLegacyDuplicates @{'other/index.html'=2}} | Should -Not -Throw
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: other/index.html (2)') -AllowedLegacyDuplicates @{'other/index.html'=2}).Outcome | Should -Be fail
    }
}
