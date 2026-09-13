BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
}
Describe 'JSON publication indexes' {
    BeforeEach {
        $site=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory("$site/guide")|Out-Null
        [IO.File]::WriteAllText("$site/guide/index.html",'<h1>Guide</h1>')
    }
    It 'checks nested catalogue links and required guide entries' {
        [IO.File]::WriteAllText("$site/translations.json",'[{"RelPermalink":"/guide/","Versions":[{"RelPermalink":"/missing/"}]}]')
        $result=Test-GuideJsonIndexes -ArtifactRoot $site -BaseUri https://preview.example/ -Indexes @(@{route='/translations.json';requiredRoutes=@('/guide/','/second/')})
        $result.Findings.Code | Should -Contain 'JSON_INDEX_TARGET_MISSING'
        $result.Findings.Code | Should -Contain 'JSON_INDEX_ENTRY_MISSING'
    }
    It 'rejects excluded URLs even when the corresponding file exists' {
        [IO.File]::WriteAllText("$site/pages.json",'[{"url":"https://preview.example/guide/"}]')
        $result=Test-GuideJsonIndexes -ArtifactRoot $site -BaseUri https://preview.example/ -Indexes @(@{route='/pages.json';requiredRoutes=@()}) -ForbiddenPaths guide
        $result.Findings.Code | Should -Contain 'JSON_INDEX_FORBIDDEN_TARGET'
    }
    It 'rejects disabled languages in a syntactically valid index' {
        [IO.File]::WriteAllText("$site/languages.json",'{"languages":[{"code":"en"},{"code":"min"}],"totalEnabledLanguages":1}')
        $result=Test-GuideJsonIndexes -ArtifactRoot $site -BaseUri https://preview.example/ -Indexes @(@{route='/languages.json';requiredRoutes=@()}) -EnabledLanguages en
        $result.Findings.Code | Should -Contain 'JSON_INDEX_LANGUAGES_DIFFER'
        $result.Findings.Code | Should -Contain 'JSON_INDEX_LANGUAGE_COUNT'
    }
    It 'accepts an intentionally empty index and blocks a malformed URL' {
        [IO.File]::WriteAllText("$site/pages.json",'[]')
        (Test-GuideJsonIndexes -ArtifactRoot $site -BaseUri https://preview.example/ -Indexes @(@{route='/pages.json';requiredRoutes=@()})).Outcome | Should -Be pass
        [IO.File]::WriteAllText("$site/pages.json",'[{"url":"javascript:alert(1)"}]')
        (Test-GuideJsonIndexes -ArtifactRoot $site -BaseUri https://preview.example/ -Indexes @(@{route='/pages.json';requiredRoutes=@()})).Findings.Code | Should -Contain 'JSON_INDEX_URL_INVALID'
    }
    It 'accepts a complete index and ignores external references' {
        [IO.File]::WriteAllText("$site/pages.json",'[{"url":"/guide/"},{"url":"https://external.example/unavailable"}]')
        $result=Test-GuideJsonIndexes -ArtifactRoot $site -BaseUri https://preview.example/ -Indexes @(@{route='/pages.json';requiredRoutes=@('/guide/')})
        $result.Outcome | Should -Be pass
    }
}
