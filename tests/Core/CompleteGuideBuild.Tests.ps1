BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/GuideSiteBuild/Invoke-GuideSiteBuild.ps1"
    function Install-GuideBuildDependencies {}
    function Invoke-GuideArtifactDeployment { param($DeploymentRoot,$WorkspaceRoot,$SourceCommit,$Target,$DeploymentEnvironment,$DeploymentAdapter,$ExpectedUrl) }
    function git { $global:LASTEXITCODE=0; 'a'*40 }
}
Describe 'Complete local guide-site execution' {
    BeforeEach {
        $script:GuideBuildModuleRoot=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory("$script:GuideBuildModuleRoot/GuideSiteBuild")|Out-Null
        $global:OgpStages=[Collections.Generic.List[string]]::new()
        'param($Stage,$BaseUrl,$Target,$WorkspaceRoot,$PolicyPath,$OutputPath,$Version) $global:OgpStages.Add("Build:$OutputPath"); if($global:OgpBuildFails){throw "Build rejected"}'|Set-Content "$script:GuideBuildModuleRoot/GuideSiteBuild/Build-GuideSite.ps1"
        'param($WorkspaceRoot,$OutputPath,$Target,$Version) $global:OgpStages.Add("Confirm:$OutputPath")'|Set-Content "$script:GuideBuildModuleRoot/GuideSiteBuild/Confirm-GuideSiteDeployment.ps1"
        'param($WorkspaceRoot,$OutputPath,$PolicyPath,$DeploymentUrl,$Target,$Version) $global:OgpStages.Add("Verify:$OutputPath|$DeploymentUrl")'|Set-Content "$script:GuideBuildModuleRoot/GuideSiteBuild/Verify-GuideSiteDeployment.ps1"
        $global:OgpBuildFails=$false
        Mock Invoke-GuideArtifactDeployment { $global:OgpStages.Add("Deploy:$DeploymentRoot");[pscustomobject]@{url='https://preview.example.test/'} }
        $arguments=@{WorkspaceRoot=$TestDrive;PolicyPath='policy.json';Version='1.0.0-preview';Target='preview';OutputPath='.processing/run';DeploymentEnvironment='preview'}
    }
    It 'uses one output directory and the returned hosting URL through Verify' {
        Invoke-GuideSiteBuild @arguments -Deploy
        $global:OgpStages[0]|Should -Be 'Build:.processing/run'
        $global:OgpStages[1]|Should -Be 'Confirm:.processing/run'
        $global:OgpStages[2]|Should -Be "Deploy:$(Join-Path $TestDrive '.processing/run')"
        $global:OgpStages[3]|Should -Be 'Verify:.processing/run|https://preview.example.test/'
    }
    It 'does not deploy during an ordinary local build' {
        Invoke-GuideSiteBuild @arguments
        Should -Invoke Invoke-GuideArtifactDeployment -Times 0 -Exactly
        $global:OgpStages.Count|Should -Be 1
    }
    It 'never deploys when the preceding build or validation fails' {
        $global:OgpBuildFails=$true
        {Invoke-GuideSiteBuild @arguments -Deploy}|Should -Throw '*Build rejected*'
        Should -Invoke Invoke-GuideArtifactDeployment -Times 0 -Exactly
    }
}
AfterAll {Remove-Variable OgpStages,OgpBuildFails -Scope Global -ErrorAction SilentlyContinue}
