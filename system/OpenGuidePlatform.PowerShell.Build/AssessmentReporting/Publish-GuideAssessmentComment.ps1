function Invoke-GuideGitHubRequest {
    param([string]$Method,[string]$Endpoint,$Body)
    $command=Get-Command gh -CommandType Application -ErrorAction Stop|Select-Object -First 1
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$command.Source;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.RedirectStandardInput=$true
    foreach($arg in @('api','--hostname','github.com','--method',$Method,$Endpoint)){$start.ArgumentList.Add($arg)}
    if($null -ne $Body){$start.ArgumentList.Add('--input');$start.ArgumentList.Add('-')}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try {
        $null=$process.Start()
        $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if($null -ne $Body){$process.StandardInput.Write(($Body|ConvertTo-Json -Depth 100))}
        $process.StandardInput.Close()
        if(-not $process.WaitForExit(30000)){$process.Kill($true);throw 'GitHub report request timed out; inspect the run marker before retrying.'}
        $raw=$stdout.GetAwaiter().GetResult();$errorText=$stderr.GetAwaiter().GetResult()
        if($process.ExitCode -ne 0){throw "GitHub report request failed: $errorText"}
        ConvertFrom-Json -InputObject $raw -ErrorAction Stop
    } finally {$process.Dispose()}
}
function Publish-GuideAssessmentComment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]$Assessment,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')][string]$Repository,
        [Parameter(Mandatory)][ValidateRange(1,2147483647)][int]$PullRequestNumber,
        [Parameter(Mandatory)][ValidateRange(1,9223372036854775807)][long]$RunId,
        [ValidateRange(1,2147483647)][int]$RunAttempt=1,
        [ValidatePattern('^[A-Za-z0-9_\[\]-]+$')][string]$ReporterLogin='github-actions[bot]'
    )
    try {
        $schema=Join-Path $PSScriptRoot '../../OpenGuidePlatform.PowerShell.Core/Contracts/assessment.schema.json'
        if(-not (Test-Json -Json ($Assessment|ConvertTo-Json -Depth 100) -SchemaFile $schema -ErrorAction Stop)){throw 'Assessment does not satisfy its contract.'}
        $prPath="repos/$Repository/pulls/$PullRequestNumber"
        $pr=Invoke-GuideGitHubRequest GET $prPath
        if($pr.state -ne 'open' -or $pr.head.sha -cne $Assessment.sourceCommit){
            return [pscustomobject]@{Outcome='skipped';Code='REPORT_SUPERSEDED';Message='The PR is closed or its current head differs from the assessed commit.'}
        }
        $marker="<!-- openguide-assessment:$RunId/$RunAttempt/$($Assessment.target)/$($Assessment.stage)/$($Assessment.sourceCommit) -->"
        $body=$marker+"`nAssessment for this commit and run only. [Workflow evidence](https://github.com/$Repository/actions/runs/$RunId).`n`n"+(ConvertTo-GuideAssessmentMarkdown $Assessment)
        if($body.Length -gt 65000){throw 'Report exceeds comment size budget; use retained assessment artifacts instead.'}
        $commentPath="repos/$Repository/issues/$PullRequestNumber/comments"
        for($page=1;$page -le 100;$page++){
            $comments=@(Invoke-GuideGitHubRequest GET "${commentPath}?per_page=100&page=$page")
            foreach($comment in $comments){
                if($comment.user.login -ceq $ReporterLogin -and $comment.body.StartsWith($marker,[StringComparison]::Ordinal)){
                    if($comment.body -cne $body){throw 'An immutable report with this run identity already has different content.'}
                    return [pscustomobject]@{Outcome='delivered';Code='REPORT_ALREADY_DELIVERED';Message='This exact report is already present.'}
                }
            }
            if($comments.Count -lt 100){break}
            if($page -eq 100){throw 'Comment pagination limit reached; delivery state is unknown.'}
        }
        # Recheck immediately before POST. Reports are append-only and explicitly scoped;
        # a head change during the POST cannot overwrite or relabel any newer report.
        $pr=Invoke-GuideGitHubRequest GET $prPath
        if($pr.state -ne 'open' -or $pr.head.sha -cne $Assessment.sourceCommit){
            return [pscustomobject]@{Outcome='skipped';Code='REPORT_SUPERSEDED';Message='The PR changed while report delivery was being prepared.'}
        }
        if(-not $PSCmdlet.ShouldProcess("$Repository#$PullRequestNumber","Post immutable assessment for run $RunId/$RunAttempt")){
            return [pscustomobject]@{Outcome='skipped';Code='REPORT_NOT_POSTED';Message='Publication was not requested by ShouldProcess.'}
        }
        $null=Invoke-GuideGitHubRequest POST $commentPath @{body=$body}
        [pscustomobject]@{Outcome='delivered';Code='REPORT_DELIVERED';Message='Commit-scoped assessment posted without editing other reports.'}
    } catch {
        [pscustomobject]@{Outcome='failed';Code='REPORT_DELIVERY_FAILED';Message=$_.Exception.Message}
    }
}