BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
}
Describe 'Artifact assessment retains missing-evidence failures' {
    BeforeEach {
        $run=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $artifact=Join-Path $run 'site'
        [IO.Directory]::CreateDirectory($artifact)|Out-Null
        [IO.File]::WriteAllText((Join-Path $artifact 'index.html'),'<h1>Guide</h1>')
        $log=Join-Path $run 'hugo.log';[IO.File]::WriteAllText($log,'Build completed')
        $identity=Join-Path $run 'artifact-identity.json'
        $record=New-GuideArtifactIdentity $artifact preview ('a'*40) '0.0.0'
        [IO.File]::WriteAllText($identity,($record|ConvertTo-Json -Depth 100))
    }
    It 'requires artifact, log and matching identity for success' {
        $result=Get-GuideArtifactAssessment $artifact $identity $log ('a'*40) preview
        $result.Outcome | Should -Be pass
        $result.FileCount | Should -Be 1
        $result.Findings.Count | Should -Be 0
    }
    It 'reports unavailable logs as blocked without inventing metrics' {
        $result=Get-GuideArtifactAssessment $artifact $identity (Join-Path $run 'missing.log') ('a'*40) preview
        $result.Outcome | Should -Be blocked
        $result.FileCount | Should -BeNullOrEmpty
        $result.SizeBytes | Should -BeNullOrEmpty
        $result.Findings.Code | Should -Contain VALIDATE_INPUT_UNAVAILABLE
    }
    It 'reports a missing artifact rather than an empty successful build' {
        $result=Get-GuideArtifactAssessment (Join-Path $run 'absent') $identity $log ('a'*40) preview
        $result.Outcome | Should -Be blocked
        $result.FileCount | Should -BeNullOrEmpty
    }
    It 'collects identity mismatch alongside explicit artifact failures' {
        $result=Get-GuideArtifactAssessment $artifact $identity $log ('b'*40) production -RequiredRoutes @('/missing/')
        $result.Outcome | Should -Be fail
        $result.Findings.Code | Should -Contain REQUIRED_ROUTE_MISSING
        $result.Findings.Code | Should -Contain ARTIFACT_IDENTITY_INVALID
    }
}