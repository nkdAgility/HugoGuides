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
    It 'rejects adding a legacy alias to a new language or deleting an existing declaration' {
        [IO.File]::WriteAllText("$workspace/site/content/one.fa.md","---`ntitle: Example`naliases:`n  - /download/`n---`nBody")
        (Test-GuideLegacyAliases $workspace $policy).Findings.Code | Should -Contain 'LEGACY_ALIAS_DECLARATION_CHANGED'
        [IO.File]::WriteAllText("$workspace/site/content/one.md","---`ntitle: Example`n---`nBody")
        (Test-GuideLegacyAliases $workspace $policy).Findings.Code | Should -Contain 'LEGACY_ALIAS_DECLARATION_MISSING'
    }
    It 'does not grant inactive languages or unrelated routes a duplicate exemption' {
        (Get-GuideLegacyAliasTargets $policy @('ja')).Count | Should -Be 0
        {Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: other/index.html (2)') -AllowedLegacyDuplicates @{'other/index.html'=2}} | Should -Not -Throw
        (Test-GuideArtifact "$workspace/site" -RequiredRoutes @() -HugoLog @('WARN  Duplicate target paths: other/index.html (2)') -AllowedLegacyDuplicates @{'other/index.html'=2}).Outcome | Should -Be fail
    }
}
