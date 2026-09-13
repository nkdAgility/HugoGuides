BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1') -Force
}
Describe 'Reviewed contributor updates' {
    BeforeEach {
        $policy=Get-Content -Raw (Join-Path $root 'tests/Contracts/fixtures/single-guide.site-policy.json') | ConvertFrom-Json -AsHashtable
        $policy.protectedPaths=@();$policy.guides[0].id='example'
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $folder=Join-Path $workspace 'site/data/contributions'
        [IO.Directory]::CreateDirectory($folder)|Out-Null
        $path=Join-Path $folder 'example.yaml'
        $original="# Preserve this comment`n- name: Alice`n  role: reviewer`n  weight: 1`n- name: Bob`n  role: contributor`n  url: https://example.org/bob`n"
        [IO.File]::WriteAllText($path,$original)
        $hash=(Get-FileHash $path).Hash
        $candidate=$original.Replace('weight: 1','weight: 2')
    }
    It 'applies the exact candidate to .yaml and preserves unrelated records and comments' {
        $result=Update-GuideContributions $workspace $policy example Alice $hash $candidate
        $result.Status | Should -Be updated
        [IO.File]::ReadAllText($path) | Should -BeExactly $candidate
        Test-Path (Join-Path $folder 'example.yml') | Should -BeFalse
        @(Get-ChildItem $folder).Count | Should -Be 1
    }
    It 'refuses stale reviewed input without touching the file' {
        [IO.File]::AppendAllText($path,"# other edit`n")
        $changed=(Get-FileHash $path).Hash
        { Update-GuideContributions $workspace $policy example Alice $hash $candidate } | Should -Throw '*changed since review*'
        (Get-FileHash $path).Hash | Should -Be $changed
    }
    It 'refuses changes to an unselected contributor' {
        { Update-GuideContributions $workspace $policy example Alice $hash ($candidate.Replace('example.org/bob','example.org/changed')) } | Should -Throw '*unselected*'
        (Get-FileHash $path).Hash | Should -Be $hash
    }
    It 'refuses collection deletion and unknown selections' {
        { Update-GuideContributions $workspace $policy example Alice $hash "- name: Alice`n  role: reviewer`n" } | Should -Throw '*collection*'
        { Update-GuideContributions $workspace $policy example Unknown $hash $original } | Should -Throw '*exactly one*'
    }
    It 'honors WhatIf and protected path policy' {
        Update-GuideContributions $workspace $policy example Alice $hash $candidate -WhatIf
        (Get-FileHash $path).Hash | Should -Be $hash
        $policy.protectedPaths=@('site/data/contributions/example.yaml')
        { Update-GuideContributions $workspace $policy example Alice $hash $candidate } | Should -Throw '*PROTECTED_RESOURCE*'
    }
    It 'does not create a second file when a .yaml file exists' {
        { New-GuideContributions $workspace $policy example @(@{name='Another';role='reviewer'}) } | Should -Throw '*exists*'
        Test-Path (Join-Path $folder 'example.yml') | Should -BeFalse
    }
    It 'refuses ambiguous extensions' {
        [IO.File]::WriteAllText((Join-Path $folder 'example.yml'),$original)
        { Update-GuideContributions $workspace $policy example Alice $hash $candidate } | Should -Throw '*Ambiguous*'
    }
    It 'leaves the original intact after a staging failure' {
        Mock New-GuideFile -ModuleName OpenGuidePlatform.PowerShell.Core { throw 'Simulated staging failure' }
        { Update-GuideContributions $workspace $policy example Alice $hash $candidate } | Should -Throw '*staging failure*'
        (Get-FileHash $path).Hash | Should -Be $hash
        @(Get-ChildItem $folder).Count | Should -Be 1
    }
    It 'preserves an edit observed during candidate preparation' {
        Mock New-GuideFile -ModuleName OpenGuidePlatform.PowerShell.Core {
            param($Path,$Content)
            [IO.File]::WriteAllText($Path,$Content)
            $originalPath=$Path -replace '\.candidate-[a-f0-9]+$',''
            [IO.File]::AppendAllText($originalPath,"# concurrent edit`n")
        }
        { Update-GuideContributions $workspace $policy example Alice $hash $candidate } | Should -Throw '*changed during preparation*'
        [IO.File]::ReadAllText($path) | Should -BeExactly ($original+"# concurrent edit`n")
        @(Get-ChildItem $folder).Count | Should -Be 1
    }
}