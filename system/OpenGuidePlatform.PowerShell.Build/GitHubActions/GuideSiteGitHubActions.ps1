# GitHub is an adapter. Assessment text and deployment artifacts remain data.
function Read-GuideWorkflowEvidence {
    param([string]$Path,[long]$MaximumBytes=1048576,[switch]$Json)
    $file=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -gt $MaximumBytes){throw 'Invalid evidence file or size.'}
    $text=[IO.File]::ReadAllText($file.FullName)
    if($Json){return ($text|ConvertFrom-Json -AsHashtable -ErrorAction Stop)}
    return $text
}
function Invoke-GuideGitHubApi {
    param([string]$Path,[ValidateSet('GET','POST','PATCH')][string]$Method='GET',[hashtable]$Body)
    if(-not $env:GH_TOKEN){throw 'GitHub report delivery requires GH_TOKEN.'}
    $arguments=@{Uri="https://api.github.com/$Path";Method=$Method;Headers=@{Authorization="Bearer $env:GH_TOKEN";Accept='application/vnd.github+json'};ErrorAction='Stop'}
    if($Body){$arguments.Body=$Body|ConvertTo-Json -Depth 20 -Compress;$arguments.ContentType='application/json; charset=utf-8'}
    Invoke-RestMethod @arguments
}
function Publish-GuidePrepareAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AssessmentRoot,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$')][string]$Repository,
        [Parameter(Mandatory)][long]$PullRequest,[Parameter(Mandatory)][long]$RunId,
        [Parameter(Mandatory)][string]$SourceCommit,[Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$PrepareResult
    )
    try{
        $assessment=Read-GuideWorkflowEvidence "$AssessmentRoot/assessment.json" -Json
        $markdown=Read-GuideWorkflowEvidence "$AssessmentRoot/assessment.md"
        if($SourceCommit -cnotmatch '^[a-f0-9]{40}$' -or $assessment.sourceCommit -cne $SourceCommit -or
            $assessment.schemaVersion -ne 1 -or $assessment.stage -cne 'Prepare' -or $assessment.target -cne $Target -or
            $Target -cnotin @('local','preview','production') -or $assessment.outcome -cnotin @('pass','fail','blocked') -or
            -not $markdown.StartsWith("## Prepare: $($assessment.outcome)`n",[StringComparison]::Ordinal)){
            throw 'Assessment identity or format does not match this run.'
        }
        function Test-CurrentPullRequest {
            $pr=Invoke-GuideGitHubApi -Path "repos/$Repository/pulls/$PullRequest"
            return $pr.state -ceq 'open' -and $pr.head.sha -ceq $SourceCommit
        }
        if(-not (Test-CurrentPullRequest)){return 'REPORT_SUPERSEDED'}
        $marker="<!-- openguide-assessment:$Target/Prepare -->"
        $run="https://github.com/$Repository/actions/runs/$RunId"
        $state=if($PrepareResult -ceq 'success'){'completed'}else{'did not complete successfully; recorded findings may be incomplete'}
        $body="$marker`nPrepare $state. [Workflow evidence]($run). This is the candidate assessment, not independent policy or deployment approval.`n`n$markdown"
        if($body.Length -gt 65000){throw 'Report exceeds GitHub comment size; use retained artifacts.'}
        $prior=$null;$page=1
        do{
            $comments=@(Invoke-GuideGitHubApi -Path "repos/$Repository/issues/$PullRequest/comments?per_page=100&page=$page")
            $prior=$comments|Where-Object {$_.user.login -ceq 'github-actions[bot]' -and $_.body.StartsWith($marker,[StringComparison]::Ordinal)}|Select-Object -First 1
            $page++
        }while(-not $prior -and $comments.Count -eq 100)
        if($prior -and $prior.body -ceq $body){return 'REPORT_ALREADY_DELIVERED'}
        if(-not (Test-CurrentPullRequest)){return 'REPORT_SUPERSEDED'}
        if($prior){$null=Invoke-GuideGitHubApi -Path "repos/$Repository/issues/comments/$($prior.id)" -Method PATCH -Body @{body=$body}}
        else{$null=Invoke-GuideGitHubApi -Path "repos/$Repository/issues/$PullRequest/comments" -Method POST -Body @{body=$body}}
        return 'REPORT_DELIVERED'
    }catch{throw "REPORT_DELIVERY_FAILED: $($_.Exception.Message). Assessment outcome was not changed."}
}
function Confirm-GuideDeploymentData {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DeploymentRoot,[Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$Target,[string]$DeploymentEnvironment)
    $identity=Read-GuideWorkflowEvidence "$DeploymentRoot/artifact-identity.json" -Json -MaximumBytes 16777216
    $report=Read-GuideWorkflowEvidence "$DeploymentRoot/artifact-validation.json" -Json -MaximumBytes 16777216
    if($SourceCommit -cnotmatch '^[a-f0-9]{40}$' -or $Target -cnotin @('preview','production') -or
        ($Target -ceq 'preview' -and -not $DeploymentEnvironment) -or
        $report.Outcome -cne 'pass' -or $report.SourceCommit -cne $SourceCommit -or $report.Target -cne $Target -or
        -not $identity.files -or $identity.files -isnot [array]){throw 'Deployment requires passing evidence for the expected source and target.'}
    $null=Test-GuideArtifactIdentity -ArtifactRoot "$DeploymentRoot/site" -Identity $identity -ExpectedTarget $Target -ExpectedSourceCommit $SourceCommit
    $bytes=(Get-GuideArtifactFiles "$DeploymentRoot/site"|Measure-Object Length -Sum).Sum
    if($bytes -gt 524288000){throw 'Deployment exceeds the artifact size limit.'}
    $published=Read-GuideWorkflowEvidence "$DeploymentRoot/site/.well-known/open-guide-platform.json" -Json
    if($published.sourceCommit -cne $SourceCommit -or $published.target -cne $Target -or $published.platformVersion -cne $identity.version){throw 'Published deployment identity differs from its evidence.'}
    return "Verified $($identity.files.Count) deployment files for $SourceCommit / $Target."
}
function Invoke-GuideSiteGitHubAction {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('PublishPrepare','ConfirmDeployment')][string]$Operation)
    $ErrorActionPreference='Stop'
    switch($Operation){
        PublishPrepare {
            $event=Get-Content -LiteralPath $env:GITHUB_EVENT_PATH -Raw|ConvertFrom-Json
            Publish-GuidePrepareAssessment -AssessmentRoot assessment -Repository $env:GITHUB_REPOSITORY -PullRequest $event.pull_request.number -RunId $env:GITHUB_RUN_ID -SourceCommit $env:ASSESSED_COMMIT -Target $env:ASSESSED_TARGET -PrepareResult $env:PREPARE_RESULT
        }
        ConfirmDeployment {
            Confirm-GuideDeploymentData -DeploymentRoot deployment -SourceCommit $env:EXPECTED_COMMIT -Target $env:EXPECTED_TARGET -DeploymentEnvironment $env:DEPLOYMENT_ENVIRONMENT
        }
    }
}
