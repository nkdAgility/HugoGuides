BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $output='.processing/discovery-regression/'+[guid]::NewGuid().ToString('N')
    & "$root/build.ps1" -Product GuideSite -Stage Prepare -SourcePath examples/reference-guide-site -WorkspaceRoot $root -Target preview -OutputPath $output -Version 0.0.0-local
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
    $inventory=Get-Content "$root/$output/discovered-site.json" -Raw|ConvertFrom-Json -AsHashtable
}
Describe 'Inferred guide-site validation' {
    It 'discovers the sample guides and editions without a maintained policy file' {
        Test-Path "$root/examples/reference-guide-site/guide-site.policy.json"|Should -BeFalse
        $inventory.guides.Count|Should -Be 2
        @($inventory.guides.editions).Count|Should -Be 4
        @($inventory.wrapper.requiredRoutes).Count|Should -BeGreaterThan 10
    }
    It 'infers required translation scaffolding independently of rendered output' {
        $inventory.wrapper.requiredFiles|Should -Contain 'examples/reference-guide-site/content/guide1/translations/index.ja.md'
        $inventory.wrapper.requiredFiles|Should -Contain 'examples/reference-guide-site/content/guide2/history/index.min.md'
    }
    It 'reports an inferred structural page as missing when its source is absent' {
        $status=Get-GuideWrapperStatus -WorkspaceRoot $TestDrive -Policy $inventory -Languages @('ja')
        @($status.Files|Where-Object {$_.Path -like '*/translations/index.ja.md' -and $_.State -eq 'missing'}).Count|Should -Be 2
    }
    It 'retains the permanent production language exclusion without a site policy' {
        $inventory.publication.permanentExclusions.id|Should -Contain min
    }
}
