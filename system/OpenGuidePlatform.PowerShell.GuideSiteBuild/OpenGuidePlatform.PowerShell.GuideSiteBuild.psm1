. (Join-Path $PSScriptRoot 'Versioning/GitVersion.ps1')
$script:GuideBuildModuleRoot=$PSScriptRoot
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1')
function ConvertTo-GuideAssessmentMarkdown {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Assessment)
    function Escape-ReportText($value) { [Net.WebUtility]::HtmlEncode([string]$value).Replace('|','&#124;').Replace('`','&#96;').Replace('@','&#64;').Replace("`r",' ').Replace("`n",' ') }
    $lines=[Collections.Generic.List[string]]::new()
    $lines.Add("## $(Escape-ReportText $Assessment.stage): $(Escape-ReportText $Assessment.outcome)")
    $lines.Add('')
    $lines.Add("Commit: $(Escape-ReportText $Assessment.sourceCommit) · Platform: $(Escape-ReportText $Assessment.platformVersion) · Target: $(Escape-ReportText $Assessment.target)")
    $lines.Add('')
    foreach($selection in @($Assessment.findings|Where-Object code -eq 'PLATFORM_VERSION_SELECTED')){$lines.Add((Escape-ReportText $selection.message));$lines.Add('')}
    $guideScopes=@('guide','edition','translation','download')
    $guideFindings=@($Assessment.findings | Where-Object { $_.scope -in $guideScopes -and $_.severity -in @('warning','blocker') })
    $otherFindings=@($Assessment.findings | Where-Object { $_.scope -notin $guideScopes -and $_.severity -in @('warning','blocker') })
    if($otherFindings.Count){
        $lines.Add('| Severity | Scope | Subject | Finding | What to fix |')
        $lines.Add('|---|---|---|---|---|')
        foreach($finding in $otherFindings){$lines.Add("| $(Escape-ReportText $finding.severity) | $(Escape-ReportText $finding.scope) | $(Escape-ReportText $finding.subject) | $(Escape-ReportText $finding.code): $(Escape-ReportText $finding.message) | $(Escape-ReportText $finding.remediation) |")}
    }
    $lines.Add('');$lines.Add('### Guide status');$lines.Add('')
    if($guideFindings.Count){
        $lines.Add('| Severity | Guide / edition / language / resource | Problem | What to fix |')
        $lines.Add('|---|---|---|---|')
        foreach($finding in $guideFindings){$lines.Add("| $(Escape-ReportText $finding.severity) | $(Escape-ReportText $finding.subject) | $(Escape-ReportText $finding.code): $(Escape-ReportText $finding.message) | $(Escape-ReportText $finding.remediation) |")}
    }else{$lines.Add('No guide fixes identified by these checks.')}
    if(@($Assessment.findings | Where-Object code -eq 'MODULE_CURRENT').Count){$lines.Add('');$lines.Add('Hugo module: current.')}
    $lines.Add('');$lines.Add('Artifact and live-site checks run in later stages.')
    $lines -join "`n"
}
function Write-GuideAssessmentReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Assessment,[Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$OutputPath)
    $root=[IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ([IO.Path]::IsPathRooted($OutputPath) -or $OutputPath -match '[\\:]' -or ($OutputPath.Split('/') | Where-Object { $_ -in @('..','.git') })) { throw 'Unsafe assessment output path.' }
    $output=[IO.Path]::GetFullPath((Join-Path $root $OutputPath))
    $comparison=if($IsWindows){[StringComparison]::OrdinalIgnoreCase}else{[StringComparison]::Ordinal}
    if(-not $output.StartsWith($root+[IO.Path]::DirectorySeparatorChar,$comparison)){throw 'Assessment output must be below the workspace.'}
    $cursor=$output
    while($cursor -and $cursor.Length -ge $root.Length){
        if(Test-Path -LiteralPath $cursor){if((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked assessment output is not supported.'}}
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
    # Immutable per-run folder: never overwrite a newer run or source file.
    if(Test-Path -LiteralPath $output){throw 'Assessment output already exists; use a new run directory.'}
    $json=$Assessment|ConvertTo-Json -Depth 100
    $schema=Join-Path $PSScriptRoot '../OpenGuidePlatform.PowerShell.Core/Contracts/assessment.schema.json'
    if(-not (Test-Json -Json $json -SchemaFile $schema -ErrorAction Stop)){throw 'Assessment does not satisfy its contract.'}
    $markdown=ConvertTo-GuideAssessmentMarkdown $Assessment
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output))|Out-Null
    $lockPath=$output+'.report-lock'
    $lock=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {
        if(Test-Path -LiteralPath $output){throw 'Assessment output appeared during preparation.'}
        [IO.Directory]::CreateDirectory($output)|Out-Null
        foreach($file in @(@{Name='assessment.json';Content=$json},@{Name='assessment.md';Content=$markdown})) {
            $stream=[IO.File]::Open((Join-Path $output $file.Name),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes($file.Content);$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
        }
    } finally {$lock.Dispose();[IO.File]::Delete($lockPath)}
    [pscustomobject]@{Outcome=$Assessment.outcome;JsonPath=(Join-Path $output 'assessment.json');MarkdownPath=(Join-Path $output 'assessment.md')}
}
function Get-GuideHugoConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string[]]$ConfigFiles,[ValidateSet('local','canary','preview','production')][string]$Target='local')
    $command=Get-Command hugo -CommandType Application -ErrorAction Stop|Select-Object -First 1
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$command.Source;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    foreach($argument in @('config','--quiet','--source',[IO.Path]::GetFullPath($SourcePath),'--config',($ConfigFiles -join ','),'--environment',$Target,'--format','json','--printZero')){$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try {
        $null=$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)){$process.Kill($true);throw 'Hugo effective configuration timed out.'}
        $raw=$stdout.GetAwaiter().GetResult();$diagnostics=$stderr.GetAwaiter().GetResult()
        if($process.ExitCode -ne 0){throw "Hugo configuration failed ($($process.ExitCode)): $diagnostics $raw"}
        $configuration=ConvertFrom-Json -InputObject $raw -AsHashtable -ErrorAction Stop
        if($configuration -isnot [Collections.IDictionary] -or -not $configuration.Contains('languages')){throw 'Hugo did not return effective language configuration.'}
        [pscustomobject]@{Configuration=$configuration;Diagnostics=$diagnostics;Target=$Target}
    } finally {$process.Dispose()}
}
. (Join-Path $PSScriptRoot 'ArtifactValidation/ArtifactValidation.ps1')

. (Join-Path $PSScriptRoot 'ModuleVersions/Get-GuideModuleFreshness.ps1')
. (Join-Path $PSScriptRoot 'ModuleVersions/Get-GuideModuleResolution.ps1')
. (Join-Path $PSScriptRoot 'ModuleVersions/Initialize-GuideResolvedModule.ps1')

. (Join-Path $PSScriptRoot 'Toolchain/Get-GuideHugoToolchain.ps1')
. (Join-Path $PSScriptRoot 'AssessmentReporting/Write-GuideAssessmentSummary.ps1')
. (Join-Path $PSScriptRoot 'ArtifactValidation/Get-GuideArtifactAssessment.ps1')
. (Join-Path $PSScriptRoot 'WrapperTranslations/Get-GuideEffectiveTranslations.ps1')
. (Join-Path $PSScriptRoot 'WrapperTranslations/Get-GuideSourceTranslations.ps1')
. (Join-Path $PSScriptRoot 'DeploymentVerification/Test-GuideSiteDeployment.ps1')
. (Join-Path $PSScriptRoot 'BuildContext/Get-GuidePreparedInputs.ps1')
. (Join-Path $PSScriptRoot 'BrowserValidation/Test-GuideRuntimeAnchors.ps1')
. (Join-Path $PSScriptRoot 'ArtifactValidation/Test-GuideJsonIndexes.ps1')
. (Join-Path $PSScriptRoot 'ArtifactValidation/Get-GuidePublishedDownloads.ps1')
. (Join-Path $PSScriptRoot 'GuideSiteBuild/Invoke-GuideSiteBuild.ps1')
. (Join-Path $PSScriptRoot 'Hosting/GuideArtifactDeployment.ps1')
. (Join-Path $PSScriptRoot 'Toolchain/Install-GuideBuildDependencies.ps1')
. (Join-Path $PSScriptRoot 'GitHubActions/GuideSiteGitHubActions.ps1')
. (Join-Path $PSScriptRoot 'BuildContext/Resolve-GuideDeliveryContext.ps1')
. (Join-Path $PSScriptRoot 'Discovery/Get-GuideSourcePages.ps1')
. (Join-Path $PSScriptRoot 'Discovery/New-GuideSiteDiscovery.ps1')
. (Join-Path $PSScriptRoot 'Discovery/Test-GuideLatestAliases.ps1')
Export-ModuleMember -Function Initialize-GuideResolvedModule,Get-GuideJsonFileNames,Get-GuideSourceTranslations,Get-GuidePublishedDownloads,Get-GuideArtifactFiles,Test-GuideLatestAliases,New-GuideSiteDiscovery,Resolve-GuideDeliveryContext,Get-GuideDeliveryRing,Install-GuideBuildDependencies,Invoke-GuideArtifactDeployment,Invoke-GuideSiteBuild,Publish-GuidePrepareAssessment,Confirm-GuideDeploymentData,Invoke-GuideSiteGitHubAction,Test-GuideJsonIndexes,Resolve-GuideRuntimeNavigation,Test-GuideRuntimeAnchors,Get-GuideModuleResolution,Get-GuidePreparedInputs,Assert-GuidePreparedInputs,Get-GuidePreparedBuildTools,Test-GuideSiteDeployment, ConvertTo-GuideAssessmentMarkdown,Write-GuideAssessmentReport,Get-GuideHugoConfiguration,Test-GuideArtifact,New-GuideArtifactIdentity,Test-GuideArtifactIdentity,Get-GuideModuleFreshness,Get-GuideHugoToolchain,Write-GuideAssessmentSummary,Get-GuideArtifactAssessment,Get-GuideEffectiveTranslations
