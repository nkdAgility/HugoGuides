. (Join-Path $PSScriptRoot '../../OpenGuidePlatform.PowerShell.GuideSiteBuild/Versioning/GitVersion.ps1')
function Get-PlatformBuildVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[string]$Version)
    $commit=(& git -C $WorkspaceRoot rev-parse HEAD).Trim()
    if($LASTEXITCODE -ne 0){throw 'Cannot identify the source commit. Run the build from a Git checkout.'}
    if($Version){return [pscustomobject]@{SemVer=$Version;Sha=$commit;Source='Explicit'}}
    $local=Join-Path $WorkspaceRoot '.processing/tools/gitversion'
    $name=if($IsWindows){'dotnet-gitversion.exe'}else{'dotnet-gitversion'}
    $tool=if(Test-Path "$local/$name"){Get-Item "$local/$name"}else{Get-Command dotnet-gitversion -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1}
    if(-not $tool){throw 'GitVersion is missing. Run ./build.ps1 Dependencies, or supply -Version for an explicitly versioned local build.'}
    $path=if($tool -is [IO.FileInfo]){$tool.FullName}else{$tool.Source}
    $prior=$env:DOTNET_ROLL_FORWARD
    try{
        $env:DOTNET_ROLL_FORWARD='Major'
        $actual=& $path /version
        if($LASTEXITCODE -ne 0 -or "$actual" -notmatch '^6\.') {throw 'This repository uses GitVersion 6 configuration. Run ./build.ps1 Dependencies to install a compatible tool locally; do not change the global tool.'}
        $configuration=Get-GuideGitVersionConfigurationPath -WorkspaceRoot $WorkspaceRoot
        $raw=& $path $WorkspaceRoot /config $configuration /output json /nofetch 2>&1
        if($LASTEXITCODE -ne 0){
            $detail=(@($raw|Where-Object {$_ -match 'ERROR|Exception|path too long'}|Select-Object -First 3) -join ' '); if(-not $detail){$detail=($raw -join ' ')}
            throw "GitVersion could not calculate this build version. Check the reported cause and full Git history/tags, then rerun build.ps1 Version. Details: $detail"
        }
        $result=$raw|ConvertFrom-Json
    }finally{$env:DOTNET_ROLL_FORWARD=$prior}
    if($result.Sha -cne $commit -or $result.SemVer -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$'){throw 'Calculated version does not identify this checkout. Recalculate from the intended clean Git checkout.'}
    [pscustomobject]@{SemVer=$result.SemVer;Sha=$result.Sha;Source='GitVersion'}
}
