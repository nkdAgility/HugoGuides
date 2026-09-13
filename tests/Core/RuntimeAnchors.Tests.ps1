BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
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
        $navigation=& "$root/.build/Test-GuideSiteNavigation.ps1" -ArtifactRoot $site -BaseUri https://preview.example/
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
    It 'does not need a browser when no runtime anchors are declared' {
        $result=Test-GuideRuntimeAnchors -WorkspaceRoot $root -ArtifactRoot $site -BaseUri https://preview.example/ -IdentityPath $identityPath -OutputPath '.processing/not-created'
        $result.outcome | Should -Be 'not-required'
    }
    It 'rejects a changed artifact before collecting fresh browser evidence' {
        [IO.File]::AppendAllText("$site/index.html",'changed')
        try{
            {Test-GuideRuntimeAnchors -WorkspaceRoot $root -ArtifactRoot $site -BaseUri https://preview.example/ -IdentityPath $identityPath -OutputPath '.processing/not-created' -Anchors @(@{route='/';fragment='content'})} | Should -Throw '*changed after Build*'
        }finally{[IO.File]::WriteAllText("$site/index.html",'<a href="/other/#content">Content</a><a href="#content">Wrong page</a>')}
    }
}
