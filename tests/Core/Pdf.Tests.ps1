BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1') -Force
}
Describe 'Generated PDF replacement and evidence' {
    BeforeEach {
        $policy=Get-Content -Raw (Join-Path $root 'tests/Contracts/fixtures/single-guide.site-policy.json')|ConvertFrom-Json -AsHashtable
        $policy.protectedPaths=@();$policy.guides[0].protectSource=$false
        $guide=$policy.guides[0];$edition=$guide.editions[0]
        $edition.translations[0].downloads=@(@{path='pdf/guide.pdf';handling='generated'})
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $directory=Join-Path $workspace "$($guide.contentRoot)/$($edition.path)"
        [IO.Directory]::CreateDirectory((Join-Path $directory 'pdf'))|Out-Null
        $source=Join-Path $directory 'index.md'
        [IO.File]::WriteAllText($source,"---`ntitle: Example`n---`nBody")
        $output=Join-Path $directory 'pdf/guide.pdf'
        [IO.File]::WriteAllText($output,'%PDF-original')
        $hash=(Get-FileHash $output).Hash
        $argsForPdf=@{WorkspaceRoot=$workspace;Policy=$policy;GuideId=$guide.id;EditionId=$edition.id;Language='en';DownloadPath='pdf/guide.pdf';ExpectedOutputSha256=$hash}
        Mock Get-GuidePdfToolchain -ModuleName OpenGuidePlatform.PowerShell.Core { @([pscustomobject]@{Tool='pandoc';Available=$true;Version='test'},[pscustomobject]@{Tool='xelatex';Available=$true;Version='test'}) }
        Mock Get-Command -ModuleName OpenGuidePlatform.PowerShell.Core -ParameterFilter { $Name -eq 'fc-list' } { $null }
        Mock Invoke-GuidePandoc -ModuleName OpenGuidePlatform.PowerShell.Core { param($Arguments) [IO.File]::WriteAllText($Arguments[-1],'%PDF-new');return 0 }
    }
    It 'replaces only the reviewed generated output and returns usable evidence' {
        $result=New-GuidePdf @argsForPdf -EnvironmentSha256 ('a'*64)
        $result.Status | Should -Be replaced
        [IO.File]::ReadAllText($output) | Should -BeExactly '%PDF-new'
        $plan=Get-GuidePdfPlan $workspace $policy $guide.id $edition.id en 'pdf/guide.pdf'
        (Test-GuidePdfCache $plan $result $result.Toolchain ('a'*64)).Reusable | Should -BeTrue
        (Test-GuidePdfCache $plan $result $result.Toolchain).Reason | Should -Be ENVIRONMENT_EVIDENCE_REQUIRED
        (Test-GuidePdfCache $plan $result $result.Toolchain ('b'*64)).Reusable | Should -BeFalse
        [IO.File]::AppendAllText($output,'changed')
        (Test-GuidePdfCache $plan $result $result.Toolchain ('a'*64)).Reason | Should -Be OUTPUT_CHANGED_OR_MISSING
    }
    It 'preserves the previous PDF on native failure' {
        Mock Invoke-GuidePandoc -ModuleName OpenGuidePlatform.PowerShell.Core { 42 }
        { New-GuidePdf @argsForPdf } | Should -Throw '*exit code 42*'
        (Get-FileHash $output).Hash | Should -Be $hash
        @(Get-ChildItem (Split-Path $output) -Force).Count | Should -Be 1
    }
    It 'refuses stale output evidence before generation' {
        [IO.File]::AppendAllText($output,'other edit')
        { New-GuidePdf @argsForPdf } | Should -Throw '*changed since review*'
        Should -Invoke Invoke-GuidePandoc -ModuleName OpenGuidePlatform.PowerShell.Core -Times 0
    }
    It 'preserves the previous PDF when Pandoc returns non-PDF output' {
        Mock Invoke-GuidePandoc -ModuleName OpenGuidePlatform.PowerShell.Core { param($Arguments) [IO.File]::WriteAllText($Arguments[-1],'broken');0 }
        { New-GuidePdf @argsForPdf } | Should -Throw '*not a PDF*'
        (Get-FileHash $output).Hash | Should -Be $hash
    }
    It 'refuses replacement when source changes while rendering' {
        Mock Invoke-GuidePandoc -ModuleName OpenGuidePlatform.PowerShell.Core {
            param($Arguments)
            [IO.File]::WriteAllText($Arguments[-1],'%PDF-new')
            [IO.File]::AppendAllText($Arguments[0],'changed')
            0
        }
        { New-GuidePdf @argsForPdf } | Should -Throw '*input changed*'
        (Get-FileHash $output).Hash | Should -Be $hash
    }
    It 'invalidates cached output when source or recipe changes' {
        $result=New-GuidePdf @argsForPdf -EnvironmentSha256 ('a'*64)
        [IO.File]::AppendAllText($source,'changed')
        $plan=Get-GuidePdfPlan $workspace $policy $guide.id $edition.id en 'pdf/guide.pdf'
        (Test-GuidePdfCache $plan $result $result.Toolchain ('a'*64)).Reason | Should -Be INPUT_EVIDENCE_CHANGED
    }
}