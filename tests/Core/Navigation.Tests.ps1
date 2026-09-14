BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $checker=Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/GuideSiteBuild/Test-GuideSiteNavigation.ps1'
}
Describe 'Guide-site navigation validation' {
    It 'resolves directory, asset, Unicode and fragment links beneath <base>' -ForEach @(
        @{base='https://preview.example/';prefix=''},
        @{base='https://preview.example/docs/';prefix='/docs'},
        @{base='https://preview.example/docs';prefix='/docs'}
    ) {
        $site=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory("$site/فا")|Out-Null
        [IO.File]::WriteAllText("$site/index.html",('<a href="'+$prefix+'/%D9%81%D8%A7/#heading">Guide</a><img src="'+$prefix+'/logo.png"><a href="https://external.example/missing">External</a>'))
        [IO.File]::WriteAllText("$site/فا/index.html",'<h2 id="heading">Heading</h2><a href="../logo.png">Relative asset</a>')
        [IO.File]::WriteAllText("$site/logo.png",'fixture')
        (& $checker -ArtifactRoot $site -BaseUri $base).Outcome | Should -Be pass
        [IO.File]::AppendAllText("$site/index.html",'<a href="'+$prefix+'/missing/">Broken</a>')
        (& $checker -ArtifactRoot $site -BaseUri $base).Findings.Code | Should -Contain INTERNAL_LINK_MISSING
    }
    It 'ignores sibling applications but rejects encoded separators inside the site' {
        $site=Join-Path $TestDrive 'path-boundary'
        [IO.Directory]::CreateDirectory($site)|Out-Null
        [IO.File]::WriteAllText("$site/index.html",'<a href="/docs-other/missing">Sibling</a><a href="/missing">Host</a><a href="/docs/%2f../secret">Unsafe</a>')
        $result=& $checker -ArtifactRoot $site -BaseUri https://preview.example/docs/
        $result.Findings.Count | Should -Be 1
        $result.Findings[0].Code | Should -Be INTERNAL_LINK_INVALID
    }

    It 'rejects missing language pages, broken canonical links and missing assets' {
        $site=Join-Path $TestDrive 'broken'
        [IO.Directory]::CreateDirectory($site)|Out-Null
        [IO.File]::WriteAllText("$site/index.html",'<a href="/ja/guide1/">Japanese</a><a href="/min/guide-1/latest">Minionese</a><img src="/logo.png">')
        $result=& $checker -ArtifactRoot $site -BaseUri https://preview.example/
        $result.Outcome | Should -Be fail
        $result.Findings.Count | Should -Be 3
    }
    It 'rejects an existing page that renders the wrong guide body' {
        $site=Join-Path $TestDrive 'wrong-body'
        [IO.Directory]::CreateDirectory($site)|Out-Null
        [IO.File]::WriteAllText("$site/index.html",'<h1>Translations</h1><p>No guide body</p>')
        $expectations=@(@{route='/';text='Expected guide chapter'})
        $result=& $checker -ArtifactRoot $site -BaseUri https://preview.example/ -RequiredPageContent $expectations
        $result.Outcome | Should -Be fail
        $result.Findings.Code | Should -Contain REQUIRED_PAGE_CONTENT_MISSING
        [IO.File]::WriteAllText("$site/index.html",'<h1>Expected guide chapter</h1>')
        (& $checker -ArtifactRoot $site -BaseUri https://preview.example/ -RequiredPageContent $expectations).Outcome | Should -Be pass
    }
    It 'checks same-page and cross-page anchors including encoded Unicode IDs' {
        $site=Join-Path $TestDrive 'anchors'
        [IO.Directory]::CreateDirectory("$site/guide")|Out-Null
        [IO.File]::WriteAllText("$site/index.html",'<a href="#missing">Bad</a><a href="/guide/#missing">Bad</a><a href="/guide/#%D9%81%D8%A7">Persian</a><a href="#top">Top</a><a href="#:~:text=hello">Text selection</a>')
        [IO.File]::WriteAllText("$site/guide/index.html",'<h2 id="فا">Heading</h2><a name="legacy"></a><a href="#legacy">Legacy</a>')
        $result=& $checker -ArtifactRoot $site -BaseUri https://preview.example/
        $result.Outcome | Should -Be fail
        @($result.Findings|Where-Object Code -EQ INTERNAL_ANCHOR_MISSING).Count | Should -Be 2
        $result.Anchors | Should -Be 4
    }
    It 'does not accept lookalike attributes, form names or inert markup as anchors' {
        $site=Join-Path $TestDrive 'false-anchors'
        [IO.Directory]::CreateDirectory($site)|Out-Null
        [IO.File]::WriteAllText("$site/index.html",'<a href="#fake">Missing</a><div data-id="fake" title="id=''fake''"></div><form name="fake"></form><!-- <i id="fake"></i> --><script>const html = ''<i id="fake"></i>'';</script>')
        $result=& $checker -ArtifactRoot $site -BaseUri https://preview.example/
        $result.Findings.Code | Should -Contain INTERNAL_ANCHOR_MISSING
    }
    It 'does not treat PDF page fragments as HTML IDs' {
        $site=Join-Path $TestDrive 'pdf-fragment'
        [IO.Directory]::CreateDirectory($site)|Out-Null
        [IO.File]::WriteAllText("$site/index.html",'<a href="/guide.pdf#page=2">PDF</a>')
        [IO.File]::WriteAllText("$site/guide.pdf",'%PDF- fixture')
        (& $checker -ArtifactRoot $site -BaseUri https://preview.example/).Outcome | Should -Be pass
    }
    It 'accepts existing directory routes and assets while ignoring external resources' {
        $site=Join-Path $TestDrive 'valid'
        [IO.Directory]::CreateDirectory("$site/min/guide1")|Out-Null
        [IO.File]::WriteAllText("$site/index.html",'<a href="/min/guide1/">Minionese</a><a href="https://preview.example//min/guide1/">Existing absolute URL</a><img src="/logo.png"><script src="https://cdn.example/script.js"></script>')
        [IO.File]::WriteAllText("$site/min/guide1/index.html",'<a href="/">Home</a>')
        [IO.File]::WriteAllText("$site/logo.png",'fixture')
        (& $checker -ArtifactRoot $site -BaseUri https://preview.example/).Outcome | Should -Be pass
    }
}
Describe 'Repository instruction shims and sample workflow' {
    It 'keeps real relative links to the same canonical instructions' {
        foreach($name in @('AGENTS.md','CLAUDE.md')){
            $item=Get-Item (Join-Path $root $name) -Force
            $item.LinkType | Should -Be SymbolicLink
            $item.LinkTarget.Replace('\','/') | Should -Be '.agents/agents.md'
            (Get-FileHash $item.FullName).Hash | Should -Be (Get-FileHash "$root/.agents/agents.md").Hash
        }
    }
    It 'runs a single sample target through the shared workflow' {
        $workflow=Get-Content "$root/.github/workflows/main.yaml" -Raw
        $workflow | Should -Not -Match 'matrix:'
        $workflow | Should -Match 'uses: ./\.github/workflows/guide-site-build.yaml'
    }
}
