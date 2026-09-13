function Get-GuideArtifactAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ArtifactRoot,
        [Parameter(Mandatory)][string]$IdentityPath,
        [Parameter(Mandatory)][string]$HugoLogPath,
        [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$SourceCommit,
        [Parameter(Mandatory)][string]$Target,
        [string[]]$RequiredRoutes=@('/'),
        [string[]]$RequiredDownloads=@(),
        [string[]]$ForbiddenPaths=@(),
        [object]$DownloadRequirements,
        [hashtable]$AllowedLegacyDuplicates=@{},
        [long]$MaximumBytes=524288000
    )
    $report=[ordered]@{Outcome='blocked';SourceCommit=$SourceCommit;Target=$Target;SizeBytes=$null;FileCount=$null;Findings=@()}
    try {
        $log=Get-Content -LiteralPath $HugoLogPath -ErrorAction Stop
        $validation=Test-GuideArtifact -ArtifactRoot $ArtifactRoot -RequiredRoutes $RequiredRoutes -RequiredDownloads $RequiredDownloads -ForbiddenPaths $ForbiddenPaths -MaximumBytes $MaximumBytes -HugoLog $log -AllowedLegacyDuplicates $AllowedLegacyDuplicates
        $report.Outcome=$validation.Outcome
        $report.SizeBytes=$validation.SizeBytes
        $report.FileCount=$validation.Files.Count
        $report.Findings=@($validation.Findings)
        if($DownloadRequirements){
            $downloads=Test-GuideDownloadPublication -Requirements $DownloadRequirements -ArtifactFiles $validation.Files
            $report.Findings+=@($downloads.Findings)
            if($downloads.Outcome -ne 'pass'){$report.Outcome='fail'}
        }
    } catch {
        $report.Findings+= [pscustomobject]@{Code='VALIDATE_INPUT_UNAVAILABLE';Path='Build evidence';Message="Restore the build artifact and Hugo log, then rerun Validate. $($_.Exception.Message)"}
        return $report
    }
    try {
        $identity=Get-Content -LiteralPath $IdentityPath -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop
        $null=Test-GuideArtifactIdentity -ArtifactRoot $ArtifactRoot -Identity $identity -ExpectedTarget $Target -ExpectedSourceCommit $SourceCommit
    } catch {
        $report.Outcome='fail'
        $report.Findings+= [pscustomobject]@{Code='ARTIFACT_IDENTITY_INVALID';Path='artifact-identity.json';Message=$_.Exception.Message}
    }
    $report
}