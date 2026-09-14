BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
}
Describe 'Azure hosting adapter result boundary' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $package=Join-Path $workspace '.processing/tools/swa/node_modules/@azure/static-web-apps-cli'
        [IO.Directory]::CreateDirectory($package)|Out-Null
        @{bin=@{swa='fixture.ps1'}}|ConvertTo-Json|Set-Content "$package/package.json"
        $oldToken=$env:SWA_CLI_DEPLOYMENT_TOKEN
        $env:SWA_CLI_DEPLOYMENT_TOKEN='fixture-secret-that-must-not-appear'
        Mock Get-Command -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild -ParameterFilter {$Name -eq 'node'} { [pscustomobject]@{Source=(Join-Path $PSHOME $(if($IsWindows){'pwsh.exe'}else{'pwsh'}))} }
    }
    AfterEach {$env:SWA_CLI_DEPLOYMENT_TOKEN=$oldToken}
    It 'requires a confirmed URL even when the CLI exits successfully' {
        'Write-Output "No deployment happened. $env:SWA_CLI_DEPLOYMENT_TOKEN"; exit 0'|Set-Content "$package/fixture.ps1"
        { & (Get-Module OpenGuidePlatform.PowerShell.GuideSiteBuild) { param($Root) Invoke-AzureGuideDeployment -WorkspaceRoot $Root -ArtifactRoot $Root -Environment preview } $workspace }|Should -Throw '*did not confirm a deployment URL*'
        $log=Get-ChildItem "$workspace/.processing/deployment-client" -Recurse -Filter deploy.log|Get-Content -Raw
        $log|Should -Match '\[redacted\]'
        $log|Should -Not -Match 'fixture-secret-that-must-not-appear'
    }
    It 'returns the actual URL and runs the CLI without GitHub context' {
        'if($env:GITHUB_ACTIONS -or $env:GH_TOKEN){throw "Host context leaked"}; Write-Output "Project deployed to https://preview.example.test/"; exit 0'|Set-Content "$package/fixture.ps1"
        $oldGithub=$env:GITHUB_ACTIONS;$oldGhToken=$env:GH_TOKEN
        try{
            $env:GITHUB_ACTIONS='true';$env:GH_TOKEN='fixture-github-token'
            $result=& (Get-Module OpenGuidePlatform.PowerShell.GuideSiteBuild) { param($Root) Invoke-AzureGuideDeployment -WorkspaceRoot $Root -ArtifactRoot $Root -Environment preview } $workspace
            $result.Url|Should -Be 'https://preview.example.test'
        }finally{$env:GITHUB_ACTIONS=$oldGithub;$env:GH_TOKEN=$oldGhToken}
    }
}
