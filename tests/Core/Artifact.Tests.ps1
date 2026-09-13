BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
}
Describe 'Artifact verification' {
    BeforeEach {
        $artifact=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory((Join-Path $artifact 'fa/guide'))|Out-Null
        [IO.File]::WriteAllText((Join-Path $artifact 'index.html'),'<h1>Home</h1>')
        [IO.File]::WriteAllText((Join-Path $artifact 'fa/guide/index.html'),'<h1>راهنما</h1>')
        [IO.File]::WriteAllText((Join-Path $artifact 'guide.pdf'),'%PDF-fixture')
    }
    It 'accepts explicitly observed routes and downloads for any guide path' {
        $result=Test-GuideArtifact $artifact -RequiredRoutes @('/','/fa/guide/') -RequiredDownloads @('guide.pdf')
        $result.Outcome | Should -Be pass
        $result.Files.Count | Should -Be 3
    }
    It 'collects independent artifact failures including a forbidden language directory' {
        [IO.Directory]::CreateDirectory((Join-Path $artifact 'min'))|Out-Null
        [IO.File]::WriteAllText((Join-Path $artifact 'min/index.html'),'#{Unresolved}#')
        [IO.File]::WriteAllText((Join-Path $artifact 'broken.json'),'{')
        $result=Test-GuideArtifact $artifact -RequiredRoutes @('/missing/') -RequiredDownloads @('missing.pdf') -ForbiddenPaths @('min/') -MaximumBytes 1
        $result.Outcome | Should -Be fail
        foreach($code in @('REQUIRED_ROUTE_MISSING','REQUIRED_DOWNLOAD_MISSING','FORBIDDEN_RESOURCE_PRESENT','INVALID_JSON','UNRESOLVED_TOKEN','ARTIFACT_TOO_LARGE')){$result.Findings.Code | Should -Contain $code}
    }
    It 'rejects traversal and linked entries rather than following them' {
        {Test-GuideArtifact $artifact -RequiredDownloads @('../outside.pdf')} | Should -Throw '*Unsafe*'
        $outside=Join-Path $TestDrive 'outside';[IO.Directory]::CreateDirectory($outside)|Out-Null
        try{$null=New-Item -ItemType SymbolicLink -Path (Join-Path $artifact 'linked') -Target $outside -ErrorAction Stop}catch{Set-ItResult -Skipped -Because 'Host cannot create symlinks.';return}
        {Test-GuideArtifact $artifact} | Should -Throw '*Linked*'
    }
    It 'binds the artifact to its source and target and detects modified bytes' {
        $identity=New-GuideArtifactIdentity $artifact preview ('a'*40) '0.0.0-preview'
        Test-GuideArtifactIdentity $artifact $identity preview ('a'*40) | Should -BeTrue
        {Test-GuideArtifactIdentity $artifact $identity production ('a'*40)} | Should -Throw '*expected source commit and target*'
        {Test-GuideArtifactIdentity $artifact $identity preview ('b'*40)} | Should -Throw '*expected source commit and target*'
        [IO.File]::AppendAllText((Join-Path $artifact 'index.html'),'modified')
        {Test-GuideArtifactIdentity $artifact $identity preview ('a'*40)} | Should -Throw '*changed after Build*'
    }
    It 'detects added and removed files and duplicate identity records' {
        $identity=New-GuideArtifactIdentity $artifact preview ('a'*40) '0.0.0-preview'
        [IO.File]::WriteAllText((Join-Path $artifact 'extra.html'),'extra')
        {Test-GuideArtifactIdentity $artifact $identity preview ('a'*40)} | Should -Throw '*inventory changed*'
        [IO.File]::Delete((Join-Path $artifact 'extra.html'))
        $identity.files[1]=$identity.files[0]
        {Test-GuideArtifactIdentity $artifact $identity preview ('a'*40)} | Should -Throw '*duplicate*'
    }
    It 'resolves dotted edition routes from actual artifact paths' {
        $directory=Join-Path $artifact 'guide/2026.1'
        [IO.Directory]::CreateDirectory($directory)|Out-Null
        [IO.File]::WriteAllText((Join-Path $directory 'index.html'),'<h1>Edition</h1>')
        (Test-GuideArtifact $artifact -RequiredRoutes @('/guide/2026.1','/guide/2026.1/','/guide.pdf')).Outcome | Should -Be pass
    }
    It 'resolves URL-encoded Persian paths without changing artifact filenames' {
        $directory=Join-Path $artifact 'fa/راهنما'
        [IO.Directory]::CreateDirectory($directory)|Out-Null
        [IO.File]::WriteAllText((Join-Path $directory 'index.html'),'<h1>راهنما</h1>')
        $encoded=[Uri]::EscapeDataString('راهنما')
        (Test-GuideArtifact $artifact -RequiredRoutes @("/fa/$encoded/",'/fa/راهنما/')).Outcome | Should -Be pass
    }
    It 'rejects encoded navigation, malformed escapes and ambiguous authority paths' {
        foreach($route in @('/%2e%2e/secret','/fa%2foutside/','/fa%5coutside/','//host/','/bad%2/','/a//b/','/a?query=1')){
            {Test-GuideArtifact $artifact -RequiredRoutes @($route)} | Should -Throw '*Unsafe*'
        }
    }
}