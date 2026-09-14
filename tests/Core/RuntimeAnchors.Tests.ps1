BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
    $site=Join-Path $TestDrive 'site'
    [IO.Directory]::CreateDirectory("$site/other")|Out-Null
    [IO.File]::WriteAllText("$site/index.html",'<a href="/other/#content">Content</a><a href="#content">Wrong page</a>')
    [IO.File]::WriteAllText("$site/other/index.html",'<script>setTimeout(()=>document.body.appendChild(Object.assign(document.createElement("main"),{id:"content"})),50);fetch("https://external.invalid/blocked").catch(()=>{});new WebSocket("wss://external.invalid/socket");</script>')
    $identityPath=Join-Path $TestDrive 'identity.json'
    $identity=New-GuideArtifactIdentity -ArtifactRoot $site -Target preview -SourceCommit ('a'*40) -Version fixture
    [IO.File]::WriteAllText($identityPath,($identity|ConvertTo-Json -Depth 20))
}
Describe 'Current artifact runtime anchors' {
    It 'observes JavaScript anchors, blocks external requests and never waives another page or missing ID' {
        $navigation=& "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/GuideSiteBuild/Test-GuideSiteNavigation.ps1" -ArtifactRoot $site -BaseUri https://preview.example/
        $navigation.Findings.Count | Should -Be 2
        $result=Test-GuideRuntimeAnchors -WorkspaceRoot $root -ArtifactRoot $site -BaseUri https://preview.example/ -IdentityPath $identityPath -OutputPath ('.processing/runtime-tests/'+[guid]::NewGuid().ToString('N')) -Anchors @(@{route='/other/';fragment='content'},@{route='/other/';fragment='missing'})
        $result.outcome | Should -Be fail
        $result.observations[0].exists | Should -BeTrue
        $result.observations[1].exists | Should -BeFalse
        $result.blockedRequests | Should -Contain 'https://external.invalid/blocked'
        $result.blockedRequests | Should -Contain 'wss://external.invalid/socket'
        $resolved=Resolve-GuideRuntimeNavigation $navigation $result
        $resolved.Findings.Count | Should -Be 1
        $resolved.Findings[0].TargetPage | Should -Be 'index.html'
        $resolved.Outcome | Should -Be fail
    }
    It 'loads the page and its script beneath a base path while blocking sibling applications' {
        $artifact=Join-Path $TestDrive 'subpath'
        [IO.Directory]::CreateDirectory("$artifact/guide")|Out-Null
        [IO.File]::WriteAllText("$artifact/guide/index.html",'<body><script src="/docs/anchor.js"></script></body>')
        [IO.File]::WriteAllText("$artifact/anchor.js",'document.body.insertAdjacentHTML("beforeend", "<h2 id=dynamic>Heading</h2>");fetch("/docs-other/secret").catch(()=>{});fetch("/secret").catch(()=>{});')
        $identity=New-GuideArtifactIdentity -ArtifactRoot $artifact -Target preview -SourceCommit ('a'*40) -Version fixture
        $identityFile=Join-Path $TestDrive 'subpath-identity.json'
        [IO.File]::WriteAllText($identityFile,($identity|ConvertTo-Json -Depth 20))
        $result=Test-GuideRuntimeAnchors -WorkspaceRoot $root -ArtifactRoot $artifact -BaseUri https://preview.example/docs/ -IdentityPath $identityFile -OutputPath ('.processing/runtime-tests/'+[guid]::NewGuid().ToString('N')) -Anchors @(@{route='/guide/';fragment='dynamic'})
        $result.outcome | Should -Be pass
        $result.blockedRequests | Should -Contain 'https://preview.example/docs-other/secret'
        $result.blockedRequests | Should -Contain 'https://preview.example/secret'
    }

    It 'launches browser validation from a deeply nested Windows workspace' -Skip:(-not $IsWindows) {
        $deep=Join-Path $root ('.processing/runtime-tests/'+[guid]::NewGuid().ToString('N')+'/'+('deep'*24))
        [IO.Directory]::CreateDirectory($deep)|Out-Null
        $result=Test-GuideRuntimeAnchors -WorkspaceRoot $deep -ArtifactRoot $site -BaseUri https://preview.example/ -IdentityPath $identityPath -OutputPath 'runtime' -Anchors @(@{route='/other/';fragment='content'})
        $result.outcome | Should -Be pass
        $cache=[IO.File]::ReadAllText("$deep/runtime/browser-cache.log")
        $cache.Length | Should -BeLessThan 161
        Test-Path "$deep/runtime/browser-output.log" | Should -BeTrue
    }
    It 'does not need a browser when no runtime anchors are declared' {
        $result=Test-GuideRuntimeAnchors -WorkspaceRoot $root -ArtifactRoot $site -BaseUri https://preview.example/ -IdentityPath $identityPath -OutputPath '.processing/not-created'
        $result.outcome | Should -Be 'not-required'
    }
    It 'accepts an explicitly null anchor collection from optional policy fields' {
        $result=Test-GuideRuntimeAnchors -WorkspaceRoot $root -ArtifactRoot $site -BaseUri https://preview.example/ -IdentityPath $identityPath -OutputPath '.processing/not-created' -Anchors $null
        $result.outcome | Should -Be 'not-required'
    }
    It 'rejects a changed artifact before collecting fresh browser evidence' {
        [IO.File]::AppendAllText("$site/index.html",'changed')
        try{
            {Test-GuideRuntimeAnchors -WorkspaceRoot $root -ArtifactRoot $site -BaseUri https://preview.example/ -IdentityPath $identityPath -OutputPath '.processing/not-created' -Anchors @(@{route='/';fragment='content'})} | Should -Throw '*changed after Build*'
        }finally{[IO.File]::WriteAllText("$site/index.html",'<a href="/other/#content">Content</a><a href="#content">Wrong page</a>')}
    }
}
