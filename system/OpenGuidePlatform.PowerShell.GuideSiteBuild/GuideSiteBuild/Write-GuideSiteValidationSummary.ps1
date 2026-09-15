[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputPath,[string]$SummaryPath=$env:GITHUB_STEP_SUMMARY)
$ErrorActionPreference='Stop'
function Escape-Cell($value){[Net.WebUtility]::HtmlEncode([string]$value).Replace('|','&#124;').Replace('`','&#96;').Replace('@','&#64;').Replace("`r",' ').Replace("`n",' ')}
$reportPath=Join-Path $OutputPath 'artifact-validation.json'
if([IO.File]::Exists($reportPath)){
    $report=Get-Content -LiteralPath $reportPath -Raw|ConvertFrom-Json
    $lines=@("## Validate: $(Escape-Cell $report.Outcome)",'',"Commit: $(Escape-Cell $report.SourceCommit) · Target: $(Escape-Cell $report.Target)","Files: $($report.FileCount); bytes: $($report.SizeBytes)")
    if($report.Findings.Count){
        $lines+=@('','| Finding | Path | What to fix |','|---|---|---|')
        foreach($finding in $report.Findings){$lines+="| $(Escape-Cell $finding.Code) | $(Escape-Cell $finding.Path) | $(Escape-Cell $finding.Message) |"}
    }elseif($report.Outcome -eq 'pass'){$lines+=@('','Artifact checks passed.')}
    else{$lines+=@('','Validation did not pass and supplied no diagnostic findings. Inspect artifact-validation.json and the build logs before continuing.')}
    $lines+=@('','Deployment and live verification are separate stages.')
}else{
    $lines=@('## Validate: blocked','','Build did not produce an artifact validation report. Inspect the failed build step and retained logs; do not treat missing evidence as a pass.')
}
$markdown=$lines -join "`n"
Write-Output $markdown
if($SummaryPath){[IO.File]::AppendAllText([IO.Path]::GetFullPath($SummaryPath),$markdown+"`n",[Text.UTF8Encoding]::new($false))}
