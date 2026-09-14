# GitHub is an adapter. Assessment text and deployment artifacts remain data.
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
        $assessment=Read-GuideEvidence "$AssessmentRoot/assessment.json" -Json
        $markdown=Read-GuideEvidence "$AssessmentRoot/assessment.md"
        if($SourceCommit -cnotmatch '^[a-f0-9]{40}$' -or $assessment.sourceCommit -cne $SourceCommit -or
            $assessment.schemaVersion -ne 1 -or $assessment.stage -cne 'Prepare' -or $assessment.target -cne $Target -or
            $Target -cnotin @('local','canary','preview','production') -or $assessment.outcome -cnotin @('pass','fail','blocked') -or
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
function Invoke-GuideSiteGitHubAction {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('ResolveDelivery','PublishPrepare','ConfirmDeployment','InstallDeploymentDependencies','Deploy')][string]$Operation)
    $ErrorActionPreference='Stop'
    switch($Operation){
        ResolveDelivery {
            $context=Resolve-GuideDeliveryContext -WorkspaceRoot $PWD -Target $env:SITE_TARGET -PullRequestNumber ([int]$env:SITE_PULL_REQUEST) -BaseUrl $env:SITE_BASE_URL -DeploymentEnvironment $env:DEPLOYMENT_ENVIRONMENT
            $context|ConvertTo-Json|Set-Content .processing/delivery-context.json
            foreach($entry in @{target=$context.target;url=$context.baseUrl;environment=$context.deploymentEnvironment}.GetEnumerator()){
                if($env:GITHUB_OUTPUT){[IO.File]::AppendAllText($env:GITHUB_OUTPUT,"$($entry.Key)=$($entry.Value)`n")}
            }
            Write-Host "Prepare selected $($context.target): $($context.baseUrl) (site version $($context.siteVersion))."
        }
        InstallDeploymentDependencies { Install-GuideBuildDependencies -WorkspaceRoot $PWD -Deployment }
        Deploy {
            $result=Invoke-GuideArtifactDeployment -DeploymentRoot (Join-Path $PWD 'deployment') -WorkspaceRoot $PWD -SourceCommit $env:EXPECTED_COMMIT -Target $env:EXPECTED_TARGET -DeploymentEnvironment $env:DEPLOYMENT_ENVIRONMENT -ExpectedUrl $env:SITE_BASE_URL
            if($env:GITHUB_OUTPUT){[IO.File]::AppendAllText($env:GITHUB_OUTPUT,"url=$($result.url)`n")}
            if($env:GITHUB_STEP_SUMMARY){[IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY,"## Deploy: uploaded`n`n[$($result.url)]($($result.url))`n`nCommit: $($result.sourceCommit)`n")}
            if($env:GITHUB_EVENT_PATH -and $env:GH_TOKEN){
                $event=Get-Content $env:GITHUB_EVENT_PATH -Raw|ConvertFrom-Json
                if($event.PSObject.Properties['pull_request']){
                    $pr=Invoke-GuideGitHubApi -Path "repos/$env:GITHUB_REPOSITORY/pulls/$($event.pull_request.number)"
                    if($pr.state -ceq 'open' -and $pr.head.sha -ceq $result.sourceCommit){
                        $body="Preview deployed for commit $($result.sourceCommit): [$($result.url)]($($result.url)). Live verification follows in Actions."
                        $null=Invoke-GuideGitHubApi -Path "repos/$env:GITHUB_REPOSITORY/issues/$($event.pull_request.number)/comments" -Method POST -Body @{body=$body}
                    }
                }
            }
            $result
        }
        PublishPrepare {
            $event=Get-Content -LiteralPath $env:GITHUB_EVENT_PATH -Raw|ConvertFrom-Json
            Publish-GuidePrepareAssessment -AssessmentRoot assessment -Repository $env:GITHUB_REPOSITORY -PullRequest $event.pull_request.number -RunId $env:GITHUB_RUN_ID -SourceCommit $env:ASSESSED_COMMIT -Target $env:ASSESSED_TARGET -PrepareResult $env:PREPARE_RESULT
        }
        ConfirmDeployment {
            Confirm-GuideDeploymentData -DeploymentRoot $(if($env:DEPLOYMENT_ROOT){$env:DEPLOYMENT_ROOT}else{'deployment'}) -SourceCommit $env:EXPECTED_COMMIT -Target $env:EXPECTED_TARGET -DeploymentEnvironment $env:DEPLOYMENT_ENVIRONMENT
        }
    }
}
