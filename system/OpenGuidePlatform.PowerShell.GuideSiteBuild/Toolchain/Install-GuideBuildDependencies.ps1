function Install-GuideBuildDependencies {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[switch]$Deployment)
    Install-Module powershell-yaml -MinimumVersion 0.4.12 -Scope CurrentUser -Force -Repository PSGallery
    if($Deployment){
        $cache=Join-Path $WorkspaceRoot '.processing/tools/swa'
        $npm=Get-Command $(if($IsWindows){'npm.cmd'}else{'npm'}) -CommandType Application -ErrorAction Stop|Select-Object -First 1
        & $npm.Source install --prefix $cache --ignore-scripts --no-audit --no-fund '@azure/static-web-apps-cli'
        if($LASTEXITCODE -ne 0){throw 'Azure deployment tool installation failed. Restore npm connectivity and rerun Dependencies -Deploy.'}
    }
}
