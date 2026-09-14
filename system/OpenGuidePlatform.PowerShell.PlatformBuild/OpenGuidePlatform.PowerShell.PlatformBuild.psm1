. (Join-Path $PSScriptRoot 'Diagnostics/BuildFailure.ps1')
# Platform engineering depends on the consumer Build module, never the reverse.
function Invoke-PlatformBuildOperation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Operation,[Parameter(Mandatory)][string]$WorkspaceRoot,[string]$OutputPath,[string]$Version,[string]$Repository='nkdAgility/OpenGuidePlatform')
    $operations=@{
        'Test-PlatformContracts'='Testing';'Test-PlatformCore'='Testing';'Test-HugoTranslationProbe'='Testing';'Test-DistributedSkills'='Testing'
        'Package-OpenGuidePlatform'='Packaging';'Test-OpenGuidePlatformPackage'='Packaging'
        'Publish-PlatformPreviewRelease'='Release';'Install-PlatformTestDependencies'='Toolchain'
    }
    if(-not $operations.ContainsKey($Operation)){throw "Unsupported platform operation: $Operation"}
    $arguments=@{WorkspaceRoot=$WorkspaceRoot}
    if($PSBoundParameters.ContainsKey('OutputPath')){$arguments.OutputPath=$OutputPath}
    if($PSBoundParameters.ContainsKey('Version')){$arguments.Version=$Version}
    if($Operation -eq 'Publish-PlatformPreviewRelease'){$arguments.Repository=$Repository}
    if($Operation -eq 'Test-PlatformCore'){
        & (Join-Path $PSHOME $(if($IsWindows){'pwsh.exe'}else{'pwsh'})) -NoProfile -File "$PSScriptRoot/Testing/Test-PlatformCore.ps1" -WorkspaceRoot $WorkspaceRoot
        if($LASTEXITCODE -ne 0){throw 'Platform Core acceptance failed.'}
    }else{& "$PSScriptRoot/$($operations[$Operation])/$Operation.ps1" @arguments}
}
function Test-PlatformCandidateSample {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$OutputPath,[string[]]$Targets=@('preview','production'))
    $output=Join-Path $WorkspaceRoot $OutputPath
    $manifest=Get-Content "$output/release-manifest.json" -Raw|ConvertFrom-Json
    if((Get-FileHash "$output/OpenGuidePlatform.zip").Hash -ine $manifest.sha256){throw 'Candidate package digest mismatch.'}
    $candidate=Join-Path $output ('sample-platform-'+[guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath "$output/OpenGuidePlatform.zip" -DestinationPath $candidate
    $null=& "$candidate/system/OpenGuidePlatform.GuideSite.Adoption/Confirm-PlatformPackage.ps1" -PackageRoot $candidate -Manifest $manifest
    @{schemaVersion=1;mode='candidate';sourceCommit=$manifest.sourceCommit;version=$manifest.version}|ConvertTo-Json|Set-Content "$candidate/platform-resolution.json"
    foreach($target in $Targets){
        # A fresh PowerShell process prevents the source Build module from satisfying candidate imports.
        & (Join-Path $PSHOME $(if($IsWindows){'pwsh.exe'}else{'pwsh'})) -NoProfile -File "$candidate/build.ps1" -Product GuideSite -WorkspaceRoot $WorkspaceRoot -PolicyPath examples/reference-guide-site/guide-site.policy.json -Target $target -OutputPath "$OutputPath/sample-$target"
        if($LASTEXITCODE -ne 0){throw "Packaged sample $target failed."}
    }
}
function Invoke-PlatformBuild {
    [CmdletBinding()]
    param([ValidateSet('All','Prepare','Build','Package','Sample','Release','Validate')][string]$Stage='All',
        [Parameter(Mandatory)][string]$WorkspaceRoot,[string]$OutputPath,[string]$Version='0.0.0-local',[string]$ReleaseTag,[switch]$Versions,
        [string]$Repository='nkdAgility/OpenGuidePlatform')
    $ErrorActionPreference='Stop'
    if(-not $Version){$Version='0.0.0-local'}
    if(-not $OutputPath){$OutputPath='.processing/platform/'+[guid]::NewGuid().ToString('N')}
    if($Versions){
        "PowerShell $($PSVersionTable.PSVersion)"
        foreach($tool in @('hugo','go','pandoc','xelatex')){
            $command=Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
            if(-not $command){"${tool}: unavailable";continue}
            $argument=if($tool -in @('hugo','go')){'version'}else{'--version'}
            $lines=@(& $command.Source $argument 2>&1)
            if($LASTEXITCODE -ne 0){throw "$tool version query failed"}
            $lines|Select-Object -First 1
        }
        return
    }
    if($Stage -in @('All','Prepare')){
        Import-Module "$PSScriptRoot/../OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1"
        Get-GuideHugoToolchain
    }
    if($Stage -in @('All','Build')){
        foreach($operation in @('Test-PlatformContracts','Test-PlatformCore','Test-HugoTranslationProbe')){
            Invoke-PlatformBuildOperation -Operation $operation -WorkspaceRoot $WorkspaceRoot
        }
    }
    if($Stage -in @('All','Package')){Invoke-PlatformBuildOperation -Operation Package-OpenGuidePlatform -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -Version $Version}
    if($Stage -in @('All','Validate') -and -not $ReleaseTag){Invoke-PlatformBuildOperation -Operation Test-OpenGuidePlatformPackage -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath}
    if($Stage -in @('All','Sample')){Test-PlatformCandidateSample -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath}
    if($Stage -eq 'Release'){Invoke-PlatformBuildOperation -Operation Publish-PlatformPreviewRelease -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -Repository $Repository}
    if($Stage -eq 'Validate' -and $ReleaseTag){
        $commit=(& git -C $WorkspaceRoot rev-parse HEAD).Trim()
        if($LASTEXITCODE -ne 0){throw 'Cannot resolve platform source commit.'}
        & "$WorkspaceRoot/.build/Restore-OpenGuidePlatform.ps1" -ReleaseTag $ReleaseTag -ExpectedCommit $commit -OutputPath $OutputPath
    }
}
Export-ModuleMember -Function New-PlatformBuildFailure,Write-PlatformTestSummary,Invoke-PlatformBuild,Invoke-PlatformBuildOperation,Test-PlatformCandidateSample
