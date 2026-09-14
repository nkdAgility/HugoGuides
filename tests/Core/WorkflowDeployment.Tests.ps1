BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module powershell-yaml
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
    $workflow=ConvertFrom-Yaml (Get-Content "$root/.github/workflows/guide-site-build.yaml" -Raw)
}
Describe 'Deployment validates site data using the selected platform package' {
    BeforeEach {
        $deployment=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item "$deployment/site/.well-known" -ItemType Directory -Force|Out-Null
        '<script>throw new Error("Never execute site data")</script>'|Set-Content "$deployment/site/index.html"
        @{sourceCommit=('a'*40);target='preview';platformVersion='1.0.0-preview'}|ConvertTo-Json|Set-Content "$deployment/site/.well-known/open-guide-platform.json"
        $identity=New-GuideArtifactIdentity -ArtifactRoot "$deployment/site" -SourceCommit ('a'*40) -Target preview -Version '1.0.0-preview'
        $identity|ConvertTo-Json -Depth 10|Set-Content "$deployment/artifact-identity.json"
        $report=@{Outcome='pass';SourceCommit=('a'*40);Target='preview'}
        $report|ConvertTo-Json|Set-Content "$deployment/artifact-validation.json"
        $arguments=@{DeploymentRoot=$deployment;SourceCommit=('a'*40);Target='preview';DeploymentEnvironment='35'}
    }
    It 'restores platform code separately from the site deployment data' {
        $job=$workflow.jobs.deploy
        $checkout=@($job.steps|Where-Object { $_['uses'] -like 'actions/checkout@*' })
        $checkout.Count|Should -Be 1
        $checkout[0].with.repository|Should -Be 'nkdAgility/OpenGuidePlatform'
        $checkout[0].with.ref|Should -Be '${{ needs.prepare.outputs.platform-source }}'
        ($job.steps|Where-Object { $_['uses'] -like 'actions/download-artifact@*' }).with.name|Should -Be 'GuideSite-Deployment'
        (($job.steps|ForEach-Object { $_['run'] }) -join "`n")|Should -Match 'Restore-OpenGuidePlatform.ps1 -FromWorkflow'
        (($job.steps|ForEach-Object { $_['run'] }) -join "`n")|Should -Match 'Invoke-GuideSiteGitHubAction.ps1 -Operation ConfirmDeployment'
        (($job.steps|ForEach-Object { $_['run'] }) -join "`n")|Should -Match 'Invoke-GuideSiteGitHubAction.ps1 -Operation Deploy'
        @($job.steps|Where-Object { $_['uses'] -like 'Azure/*' }).Count|Should -Be 0
    }
    It 'deploys through a consumer adapter without any GitHub environment' {
        $adapter=Join-Path $TestDrive 'hosting.ps1'
        'param($ArtifactRoot,$Target,$Environment,$ExpectedUrl) if(-not (Test-Path "$ArtifactRoot/index.html")){throw "Missing artifact"}; [pscustomobject]@{Url="https://preview.example.test/"}'|Set-Content $adapter
        $before=@{}
        foreach($item in @(Get-ChildItem Env:GITHUB_* -ErrorAction SilentlyContinue)){$before[$item.Name]=$item.Value;[Environment]::SetEnvironmentVariable($item.Name,$null)}
        try{
            $result=Invoke-GuideArtifactDeployment @arguments -WorkspaceRoot $TestDrive -DeploymentAdapter $adapter -ExpectedUrl https://preview.example.test/
            $result.url|Should -Be 'https://preview.example.test/'
            (Get-Content "$deployment/deployment.json" -Raw|ConvertFrom-Json).sourceCommit|Should -Be ('a'*40)
        }finally{foreach($key in $before.Keys){[Environment]::SetEnvironmentVariable($key,$before[$key])}}
    }
    It 'rejects production aliases before calling a preview hosting adapter' -ForEach @('prod','production','Production') {
        $arguments.DeploymentEnvironment=$_
        {Invoke-GuideArtifactDeployment @arguments -WorkspaceRoot $TestDrive -DeploymentAdapter missing.ps1}|Should -Throw '*production aliases are forbidden*'
    }
    It 'refuses dirty source before invoking hosting' {
        $identity.sourceDirty=$true;$identity|ConvertTo-Json -Depth 10|Set-Content "$deployment/artifact-identity.json"
        {Invoke-GuideArtifactDeployment @arguments -WorkspaceRoot $TestDrive -DeploymentAdapter missing.ps1}|Should -Throw '*clean source evidence*'
    }
    It 'rejects an adapter that reports an unexpected destination' {
        $adapter=Join-Path $TestDrive 'wrong-host.ps1'
        'param($ArtifactRoot,$Target,$Environment,$ExpectedUrl) [pscustomobject]@{Url="https://wrong.example.test/"}'|Set-Content $adapter
        {Invoke-GuideArtifactDeployment @arguments -WorkspaceRoot $TestDrive -DeploymentAdapter $adapter -ExpectedUrl https://expected.example.test/}|Should -Throw '*different URL*'
        Test-Path "$deployment/deployment.json"|Should -BeFalse
    }
    It 'accepts matching bytes and passing evidence' {
        Confirm-GuideDeploymentData @arguments|Should -Match 'Verified 2 deployment files'
    }
    It 'rejects changes to the validated artifact' -ForEach @('tamper','extra','missing','duplicate','version','link') {
        switch($_){
            tamper { Add-Content "$deployment/site/index.html" tampered }
            extra { 'extra'|Set-Content "$deployment/site/extra.txt" }
            missing { Remove-Item "$deployment/site/index.html" }
            duplicate { $identity.files=@($identity.files[0],$identity.files[0]);$identity|ConvertTo-Json -Depth 10|Set-Content "$deployment/artifact-identity.json" }
            version { $identity.version='another';$identity|ConvertTo-Json -Depth 10|Set-Content "$deployment/artifact-identity.json" }
            link { Remove-Item "$deployment/site/index.html";New-Item "$deployment/site/index.html" -ItemType SymbolicLink -Target "$deployment/artifact-validation.json"|Out-Null }
        }
        {Confirm-GuideDeploymentData @arguments}|Should -Throw
    }
    It 'requires passing evidence for the requested source and environment' -ForEach @('failed','source','target','environment') {
        switch($_){
            failed { $report.Outcome='fail' }
            source { $report.SourceCommit='b'*40 }
            target { $arguments.Target='production' }
            environment { $arguments.DeploymentEnvironment='' }
        }
        $report|ConvertTo-Json|Set-Content "$deployment/artifact-validation.json"
        {Confirm-GuideDeploymentData @arguments}|Should -Throw '*passing evidence*'
    }
}
