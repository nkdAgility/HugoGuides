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
        $inventory.wrapper.requiredRoutes|Should -Contain '/ja/guide1/latest/'
        Test-Path "$root/$output/discovery-probe"|Should -BeFalse
    }
    It 'respects a configured directory and suffix for home JSON output' {
        $fixture=Join-Path $TestDrive 'json-path'
        New-Item "$fixture/content/guide/2024.1" -ItemType Directory -Force|Out-Null
        ""|Set-Content "$fixture/hugo.preview.yaml"
        "---`ntype: guide`nlayout: root`n---"|Set-Content "$fixture/content/guide/_index.md"
        "---`ntype: guide`nversion: 2024.1`n---`nBody"|Set-Content "$fixture/content/guide/2024.1/index.md"
        Mock Get-GuideSourcePages -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { @() }
        Mock Get-GuideHugoConfiguration -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild {
            @{Configuration=@{contentdir='content';defaultcontentlanguage='en';defaultcontentlanguageinsubdir=$false;languages=@{en=@{disabled=$false}};outputs=@{home=@('catalogue')};outputformats=@{html=@{mediatype='text/html'};catalogue=@{path='api';basename='catalogue';mediatype='application/json'}};mediatypes=@{'application/json'=@{suffixes=@('jsn')}}}}
        }
        $found=New-GuideSiteDiscovery -WorkspaceRoot $TestDrive -SourcePath json-path -ConfigFiles @('hugo.yaml') -Target preview -OutputPath .processing/discovery
        $found.wrapper.jsonIndexes.route|Should -Contain '/api/catalogue.jsn'
        $found|ConvertTo-Json -Depth 50|Set-Content "$fixture/policy.json"
        {Import-GuidePolicy "$fixture/policy.json"}|Should -Not -Throw
        "---`ntitle: Home`noutputs: [html]`n---"|Set-Content "$fixture/content/_index.md"
        $withoutJson=New-GuideSiteDiscovery -WorkspaceRoot $TestDrive -SourcePath json-path -ConfigFiles @('hugo.yaml') -Target preview -OutputPath .processing/discovery
        @($withoutJson.wrapper.jsonIndexes).Count|Should -Be 0
    }
    It 'requires configured JSON outputs even when no output file exists' {
        $result=Test-GuideJsonIndexes -ArtifactRoot $TestDrive -BaseUri https://example.test/ -Indexes $inventory.wrapper.jsonIndexes
        $result.Outcome|Should -Be fail
        $result.Findings.Code|Should -Contain JSON_INDEX_INVALID
    }
    It 'retains independent source routes when pages are absent from the artifact' {
        $result=Test-GuideArtifact -ArtifactRoot $TestDrive -RequiredRoutes $inventory.wrapper.requiredRoutes
        $result.Outcome|Should -Be fail
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

Describe 'Source-only discovery' {
    It 'reads guide metadata without parsing or executing consumer shortcodes' {
        $fixture=Join-Path $TestDrive 'source-only'
        New-Item "$fixture/content/guide/2024.1" -ItemType Directory -Force|Out-Null
        "---`ntitle: Guide`ntype: guide`nlayout: root`n---"|Set-Content "$fixture/content/guide/_index.md"
        "---`ntitle: Published`ntype: guide`nversion: 2024.1`n---`n{{< consumer-shortcode >}}"|Set-Content "$fixture/content/guide/2024.1/index.md"
        Mock Get-GuideHugoConfiguration -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild {
            @{Configuration=@{contentdir='content';defaultcontentlanguage='en';defaultcontentlanguageinsubdir=$false;languages=@{en=@{disabled=$false}};outputs=@{home=@()};outputformats=@{};mediatypes=@{}}}
        }
        Mock Get-GuideSourcePages -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { @() }
        $found=New-GuideSiteDiscovery -WorkspaceRoot $TestDrive -SourcePath source-only -ConfigFiles @('hugo.yaml') -Target preview -OutputPath .processing/discovery
        $found.guides[0].editions[0].translations[0].intent|Should -Be web
        Should -Invoke Get-GuideSourcePages -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild -Times 1 -Exactly
        Test-Path "$TestDrive/.processing/discovery"|Should -BeFalse
    }
}

Describe 'Non-rendering Hugo metadata' {
    BeforeAll { . "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/Discovery/Get-GuideSourcePages.ps1" }
    It 'preserves custom URLs and ring filtering without evaluating shortcodes or writing a site' {
        $fixture=Join-Path $TestDrive 'hugo-source'
        New-Item "$fixture/content","$fixture/layouts/_shortcodes" -ItemType Directory -Force|Out-Null
        "baseURL: https://example.test/docs/`nlanguages:`n  en:`n    weight: 1`n  min:`n    disabled: true"|Set-Content "$fixture/hugo.yaml"
        '{{ errorf "SHORTCODE_MUST_NOT_RENDER_IN_PREPARE" }}'|Set-Content "$fixture/layouts/_shortcodes/probe.html"
        foreach($item in @(
            @{name='published';metadata='url: /bespoke/'},
            @{name='draft';metadata='draft: true'},
            @{name='future';metadata='publishDate: 2999-01-01'},
            @{name='expired';metadata='expiryDate: 2000-01-01'}
        )){ "---`ntitle: $($item.name)`n$($item.metadata)`n---`n{{< probe >}}"|Set-Content "$fixture/content/$($item.name).md" }
        "---`ntitle: Disabled`n---"|Set-Content "$fixture/content/published.min.md"
        "---`ntitle: json-only`noutputs: [json]`n---"|Set-Content "$fixture/content/json-only.md"
        $config=@{builddrafts=$false;buildfuture=$false;buildexpired=$false}
        $published=@(Get-GuideSourcePages -SourcePath $fixture -ConfigFiles @('hugo.yaml') -Target production -Configuration $config)
        $published.Count|Should -Be 2
        ($published|Where-Object title -eq published).permalink|Should -Be 'https://example.test/docs/bespoke/'
        $all=@(Get-GuideSourcePages -SourcePath $fixture -ConfigFiles @('hugo.yaml') -Target canary -Configuration @{builddrafts=$true;buildfuture=$true;buildexpired=$true})
        $all.Count|Should -Be 5
        ($published|Where-Object title -eq json-only).permalink|Should -Match '\.json$'
        Test-Path "$fixture/public"|Should -BeFalse
    }
}
