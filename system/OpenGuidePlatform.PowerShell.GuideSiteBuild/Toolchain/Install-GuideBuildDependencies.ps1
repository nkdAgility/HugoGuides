function Install-GuideBuildDependencies {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[switch]$Deployment)
    Install-Module powershell-yaml -MinimumVersion 0.4.12 -Scope CurrentUser -Force -Repository PSGallery
    if(Test-Path (Join-Path $WorkspaceRoot '.github/GitVersion.yml')){
        $tools=Join-Path $WorkspaceRoot '.processing/tools/gitversion'
        if(-not (Test-Path "$tools/dotnet-gitversion*")){
            & dotnet tool install GitVersion.Tool --version '5.*' --tool-path $tools
            if($LASTEXITCODE -ne 0){throw 'GitVersion installation failed. Install the .NET SDK, restore NuGet connectivity, and rerun Dependencies.'}
        }
    }
    if($Deployment){
        $cache=Join-Path $WorkspaceRoot '.processing/tools/swa'
        $npm=Get-Command $(if($IsWindows){'npm.cmd'}else{'npm'}) -CommandType Application -ErrorAction Stop|Select-Object -First 1
        & $npm.Source install --prefix $cache --ignore-scripts --no-audit --no-fund '@azure/static-web-apps-cli'
        if($LASTEXITCODE -ne 0){throw 'Azure deployment tool installation failed. Restore npm connectivity and rerun Dependencies -Deploy.'}
    }
}
