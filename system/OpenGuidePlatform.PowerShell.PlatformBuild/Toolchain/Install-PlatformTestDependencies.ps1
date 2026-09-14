#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot)
$ErrorActionPreference='Stop'
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -Repository PSGallery
Install-Module powershell-yaml -MinimumVersion 0.4.12 -Scope CurrentUser -Force -Repository PSGallery

$tools=Join-Path $WorkspaceRoot '.processing/tools/gitversion'
if(-not (Test-Path "$tools/dotnet-gitversion*") ){
    & dotnet tool install GitVersion.Tool --version '5.*' --tool-path $tools
    if($LASTEXITCODE -ne 0){throw 'GitVersion installation failed. Install the .NET SDK and restore NuGet connectivity, then rerun Dependencies.'}
}
