BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $module=Join-Path $root 'system/OpenGuidePlatform.Hugo.Guides'
    $fixture=Join-Path $TestDrive 'rendering'
    foreach($directory in @('themes/guides/layouts/_partials','layouts/guide','content/guide/latest/pdf','data/contributions')){
        [IO.Directory]::CreateDirectory("$fixture/$directory")|Out-Null
    }
    # Exercise the production partials and three callers with small, deterministic
    # content. The fixture wrapper omits unrelated theme assets and remote modules.
    Copy-Item "$module/layouts/_partials/*" "$fixture/themes/guides/layouts/_partials/" -Recurse
    Copy-Item "$module/layouts/index.html" "$fixture/themes/guides/layouts/index.html"
    Copy-Item "$module/layouts/guide/details.html" "$fixture/layouts/guide/details.html"
    [IO.File]::WriteAllText("$fixture/layouts/baseof.html",'<html><body>{{ block "main" . }}{{ end }}</body></html>')
    [IO.File]::WriteAllText("$fixture/layouts/guide/probe.html",'{{ define "main" }}{{ partial "components/guide/guide-creators.html" . }}<script id="catalogue" type="application/json">{{ partial "functions/get-guide-translations-for-version.html" . | jsonify | safeJS }}</script>{{ end }}')
    [IO.File]::WriteAllText("$fixture/hugo.yaml",@'
baseURL: https://fixture.example/
theme: guides
defaultContentLanguage: en
disableKinds: [taxonomy, term, RSS, sitemap]
languages:
  en: {languageName: English}
  fa: {languageName: Persian}
  fr: {languageName: French}
  ja: {languageName: Japanese}
  min: {languageName: Minionese}
  es-ES: {languageName: Spanish}
  pt-BR: {languageName: Portuguese}
'@)
    [IO.File]::WriteAllText("$fixture/data/contributions/guide.yaml",@'
- name: Fixture Creator
  githubUsername: fixture-creator
  role: creator
  founder: true
  weight: 1
- name: Fixture Contributor
  gravatarHash: fixture-hash
  role: contributor
  founder: true
  weight: 2
'@)
    [IO.File]::WriteAllText("$fixture/content/guide/_index.md","---`ntitle: Fixture guide`ntype: guide`nlayout: details`n---`nGuide overview.")
    foreach($language in @('en','fa','fr','ja','min','es-ES','pt-BR')){
        [IO.File]::WriteAllText("$fixture/content/guide/latest/index.$($language.ToLowerInvariant()).md","---`ntitle: Fixture guide $language`ntype: guide`nlayout: probe`n---`nThis is a complete guide body with enough words to represent an online translation in the catalogue.")
    }
    # en-us is deliberately NOT a configured language, so Hugo exposes that PDF
    # in every translation's resources. Spanish deliberately has no PDF.
    foreach($language in @('en','en-us','fa','fr','ja','min','pt-br')){
        [IO.File]::WriteAllText("$fixture/content/guide/latest/pdf/guide.$language.pdf","%PDF fixture $language")
    }
    $log=@(& hugo --source $fixture --destination "$fixture/public" 2>&1)
    if($LASTEXITCODE -ne 0 -or @($log|Where-Object {$_ -match '^ERROR'}).Count){throw "Hugo fixture failed: $($log -join [Environment]::NewLine)"}
    $html=[IO.File]::ReadAllText("$fixture/public/min/guide/latest/index.html")
    $json=[regex]::Match($html,'(?s)<script id="catalogue" type="application/json">(.*?)</script>').Groups[1].Value
    $catalogue=ConvertFrom-Json $json
}
Describe 'Guide contributor rendering' {
    It 'renders creator names and avatars from the real creator partial' {
        $html | Should -Match 'Fixture Creator'
        $html | Should -Match 'avatars.githubusercontent.com/fixture-creator'
    }
    It 'renders contributor identities on the homepage and guide details page' {
        foreach($page in @('index.html','guide/index.html')){
            $rendered=[IO.File]::ReadAllText("$fixture/public/$page")
            $rendered | Should -Match 'Fixture Creator'
            $rendered | Should -Match 'Fixture Contributor'
            $rendered | Should -Match 'avatars.githubusercontent.com/fixture-creator'
            $rendered | Should -Match 'gravatar.com/avatar/fixture-hash'
        }
    }
}
Describe 'Translation PDF resource selection' {
    It 'selects each language PDF rather than a shared untagged English resource' {
        foreach($language in @('en','fa','fr','ja','min','pt-br')){
            $row=@($catalogue|Where-Object Language -EQ $language)
            $row.Count | Should -Be 1
            $row[0].ReadPDF | Should -BeTrue -Because $language
            $row[0].PathPdf | Should -Match ([regex]::Escape("guide.$language.pdf")+'$')
            $relative=[uri]::UnescapeDataString($row[0].PathPdf).TrimStart('/')
            Test-Path -LiteralPath "$fixture/public/$relative" | Should -BeTrue
        }
    }
    It 'keeps PDF-only languages and does not invent downloads for missing translations' {
        $english=@($catalogue|Where-Object Language -EQ 'en-us')
        $english[0].ReadPDF | Should -BeTrue
        $english[0].PathPdf | Should -Match 'guide.en-us.pdf$'
        $spanish=@($catalogue|Where-Object Language -EQ 'es-es')
        $spanish.Count | Should -Be 1
        $spanish[0].ReadPDF | Should -BeFalse
        $spanish[0].PathPdf | Should -BeNullOrEmpty
        $spanish[0].ReadOnline | Should -BeTrue
    }
}
