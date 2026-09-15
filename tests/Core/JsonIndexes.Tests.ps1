BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
}
Describe 'JSON publication indexes' {
    BeforeEach {
        $site=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory("$site/guide")|Out-Null
        [IO.File]::WriteAllText("$site/guide/index.html",'<h1>Guide</h1>')
    }
    It 'validates a non-home index using the configured JSON media suffix' {
        $config=@{outputformats=@{catalogue=@{basename='catalogue';mediatype='application/json'}};mediatypes=@{'application/json'=@{suffixes=@('jsn')}}}
        $names=@(Get-GuideJsonFileNames -Configuration $config)
        $names|Should -Contain 'catalogue.jsn'
        '[{"url":"/missing/"}]'|Set-Content "$site/guide/catalogue.jsn"
        $indexes=@(Get-GuideArtifactFiles $site|Where-Object {[IO.Path]::GetFileName($_.Path) -in $names}|ForEach-Object {@{route='/'+$_.Path;requiredRoutes=@()}})
        (Test-GuideJsonIndexes -ArtifactRoot $site -BaseUri https://example.test/ -Indexes $indexes).Findings.Code|Should -Contain JSON_INDEX_TARGET_MISSING
    }
    It 'does not authorize PDF mappings from a static index impostor' {
        New-Item "$site/static" -ItemType Directory|Out-Null
        '[{"VersionPath":"guide/2024.1","Language":"en","PathPdf":"/extra.pdf"}]'|Set-Content "$site/static/translations.json"
        '[]'|Set-Content "$site/translations.json"
        $files=@(Get-GuideArtifactFiles $site)
        @(Get-GuidePublishedDownloads -ArtifactFiles $files -BaseUri https://example.test/ -Indexes @(@{route='/translations.json';requiredRoutes=@()})).Count|Should -Be 0
    }
    It 'preserves an explicitly empty media delimiter' {
        $config=@{outputformats=@{catalogue=@{basename='catalogue';mediatype='application/json'}};mediatypes=@{'application/json'=@{suffixes=@('jsn');delimiter=''}}}
        @(Get-GuideJsonFileNames -Configuration $config)|Should -Contain 'cataloguejsn'
    }
    It 'checks artifact-relative required and forbidden routes beneath <base>' -ForEach @(
        @{base='https://preview.example/';prefix=''},
        @{base='https://preview.example/docs/';prefix='/docs'},
        @{base='https://preview.example/docs';prefix='/docs'}
    ) {
        [IO.File]::WriteAllText("$site/pages.json",('[{"url":"'+$prefix+'/guide/"},{"url":"guide/"}]'))
        $parameters=@{ArtifactRoot=$site;BaseUri=$base;Indexes=@(@{route='/pages.json';requiredRoutes=@('/guide/')})}
        (Test-GuideJsonIndexes @parameters).Outcome | Should -Be pass
        (Test-GuideJsonIndexes @parameters -ForbiddenPaths guide).Findings.Code | Should -Contain JSON_INDEX_FORBIDDEN_TARGET
    }
    It 'does not count sibling application URLs as entries in this artifact' {
        [IO.File]::WriteAllText("$site/pages.json",'[{"url":"/guide/"},{"url":"/docs-other/guide/"},{"url":"https://other.example/docs/guide/"}]')
        $result=Test-GuideJsonIndexes -ArtifactRoot $site -BaseUri https://preview.example/docs/ -Indexes @(@{route='/pages.json';requiredRoutes=@('/guide/')})
        $result.Findings.Count | Should -Be 1
        $result.Findings.Code | Should -Be JSON_INDEX_ENTRY_MISSING
    }
    It 'rejects encoded path separators instead of treating them as filesystem navigation' {
        [IO.File]::WriteAllText("$site/pages.json",'[{"url":"/docs/%2f../guide/"}]')
        (Test-GuideJsonIndexes -ArtifactRoot $site -BaseUri https://preview.example/docs/ -Indexes @(@{route='/pages.json';requiredRoutes=@()})).Findings.Code | Should -Contain JSON_INDEX_INVALID
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
