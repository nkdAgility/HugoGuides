BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $checker=Join-Path $root '.build/Test-GuideSiteNavigation.ps1'
}
Describe 'Guide-site navigation validation' {
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
    It 'accepts existing directory routes and assets while ignoring external resources' {
        $site=Join-Path $TestDrive 'valid'
        [IO.Directory]::CreateDirectory("$site/min/guide1")|Out-Null
        [IO.File]::WriteAllText("$site/index.html",'<a href="/min/guide1/">Minionese</a><img src="/logo.png"><script src="https://cdn.example/script.js"></script>')
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
