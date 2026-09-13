BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
}
Describe 'Deployment source provenance' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory("$workspace/.processing/result/site")|Out-Null
        [IO.File]::WriteAllText("$workspace/.gitignore",'.processing/')
        & git init -q -b fixture $workspace
        & git -C $workspace add .gitignore
        & git -C $workspace -c user.name=Fixture -c user.email=fixture@example.invalid commit -q -m baseline
        $commit=(& git -C $workspace rev-parse HEAD).Trim()
        [IO.File]::WriteAllText("$workspace/.processing/result/site/index.html",'<main>Fixture</main>')
        $identity=New-GuideArtifactIdentity -ArtifactRoot "$workspace/.processing/result/site" -Target preview -SourceCommit $commit -Version fixture
        [IO.File]::WriteAllText("$workspace/.processing/result/artifact-validation.json",(@{Outcome='pass';SourceCommit=$commit;Target='preview'}|ConvertTo-Json))
        $arguments=@{WorkspaceRoot=$workspace;OutputPath='.processing/result';Target='preview';Version='fixture'}
    }
    It 'accepts explicitly clean validated artifacts' {
        [IO.File]::WriteAllText("$workspace/.processing/result/artifact-identity.json",($identity|ConvertTo-Json -Depth 10))
        {& "$root/system/OpenGuidePlatform.PowerShell.Build/GuideSiteBuild/Confirm-GuideSiteDeployment.ps1" @arguments} | Should -Not -Throw
    }
    It 'rejects dirty, missing and non-boolean source-cleanliness declarations' {
        foreach($state in @($true,'false',$null)){
            $identity.sourceDirty=$state
            if($null -eq $state){$identity.Remove('sourceDirty')}
            [IO.File]::WriteAllText("$workspace/.processing/result/artifact-identity.json",($identity|ConvertTo-Json -Depth 10))
            {& "$root/system/OpenGuidePlatform.PowerShell.Build/GuideSiteBuild/Confirm-GuideSiteDeployment.ps1" @arguments} | Should -Throw '*explicitly clean source identity*'
        }
    }
}
