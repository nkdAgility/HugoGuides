function Read-GuideEvidence {
    param([string]$Path,[long]$MaximumBytes=1048576,[switch]$Json)
    $file=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -gt $MaximumBytes){throw 'Invalid evidence file or size.'}
    $text=[IO.File]::ReadAllText($file.FullName)
    if($Json){return ($text|ConvertFrom-Json -AsHashtable -ErrorAction Stop)}
    return $text
}
function Confirm-GuideDeploymentData {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DeploymentRoot,[Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$Target,[string]$DeploymentEnvironment)
    $identity=Read-GuideEvidence "$DeploymentRoot/artifact-identity.json" -Json -MaximumBytes 16777216
    $report=Read-GuideEvidence "$DeploymentRoot/artifact-validation.json" -Json -MaximumBytes 16777216
    if($SourceCommit -cnotmatch '^[a-f0-9]{40}$' -or $Target -cnotin @('canary','preview','production') -or
        ($Target -in @('canary','preview') -and -not $DeploymentEnvironment) -or
        $report.Outcome -cne 'pass' -or $report.SourceCommit -cne $SourceCommit -or $report.Target -cne $Target -or
        -not $identity.files -or $identity.files -isnot [array]){throw 'Deployment requires passing evidence for the expected source and target.'}
    $null=Test-GuideArtifactIdentity -ArtifactRoot "$DeploymentRoot/site" -Identity $identity -ExpectedTarget $Target -ExpectedSourceCommit $SourceCommit
    $bytes=(Get-GuideArtifactFiles "$DeploymentRoot/site"|Measure-Object Length -Sum).Sum
    if($bytes -gt 524288000){throw 'Deployment exceeds the artifact size limit.'}
    $published=Read-GuideEvidence "$DeploymentRoot/site/.well-known/open-guide-platform.json" -Json
    if($published.sourceCommit -cne $SourceCommit -or $published.target -cne $Target -or $published.platformVersion -cne $identity.version){throw 'Published deployment identity differs from its evidence.'}
    return "Verified $($identity.files.Count) deployment files for $SourceCommit / $Target."
}

function Invoke-AzureGuideDeployment {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ArtifactRoot,[Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$Environment)
    if(-not $env:SWA_CLI_DEPLOYMENT_TOKEN){throw 'Azure deployment credentials are missing. Set SWA_CLI_DEPLOYMENT_TOKEN in your shell or CI secret environment, then retry Deploy.'}
    $package=Join-Path $WorkspaceRoot '.processing/tools/swa/node_modules/@azure/static-web-apps-cli'
    if(-not (Test-Path "$package/package.json")){throw 'The Azure deployment CLI is missing. Run Dependencies -Deploy before deploying.'}
    $metadata=Get-Content "$package/package.json" -Raw|ConvertFrom-Json
    $node=Get-Command node -CommandType Application -ErrorAction Stop|Select-Object -First 1
    $work=Join-Path $WorkspaceRoot ('.processing/deployment-client/'+[guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($work)|Out-Null
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$node.Source;$start.WorkingDirectory=$work;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    foreach($value in @((Join-Path $package $metadata.bin.swa),'deploy',[IO.Path]::GetFullPath($ArtifactRoot),'--env',$Environment,'--no-use-keychain','--verbose','log')){$start.ArgumentList.Add($value)}
    foreach($key in @($start.Environment.Keys|Where-Object {$_ -like 'GITHUB_*' -or $_ -eq 'GH_TOKEN'})){$null=$start.Environment.Remove($key)}
    $start.Environment['SWA_CLI_DEBUG']='log'
    $start.Environment['NO_COLOR']='1'
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try{
        $null=$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(1800000)){$process.Kill($true);throw 'Azure upload timed out. Inspect the hosting environment before retrying Deploy.'}
        $log=($stdout.GetAwaiter().GetResult()+"`n"+$stderr.GetAwaiter().GetResult()).Replace($env:SWA_CLI_DEPLOYMENT_TOKEN,'[redacted]')
        $log=[regex]::Replace($log,'\x1B\[[0-?]*[ -/]*[@-~]','')
        [IO.File]::WriteAllText("$work/deploy.log",$log)
        if($process.ExitCode -ne 0){Write-Host $log;throw "Azure upload failed ($($process.ExitCode)). Check $work/deploy.log, correct the reported hosting problem, and retry Deploy."}
        $matches=[regex]::Matches($log,'Project deployed to\s+(https://[a-zA-Z0-9.-]+(?:/[^\s]*)?)')
        if($matches.Count -ne 1){Write-Host $log;throw "Azure did not confirm a deployment URL. A zero exit code is insufficient. Check $work/deploy.log and verify the hosting service before retrying."}
        [pscustomobject]@{Url=$matches[0].Groups[1].Value.TrimEnd('/');Provider='AzureStaticWebApps'}
    }finally{$process.Dispose()}
}
function Invoke-GuideArtifactDeployment {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DeploymentRoot,[Parameter(Mandatory)][string]$WorkspaceRoot,
        [Parameter(Mandatory)][string]$SourceCommit,[Parameter(Mandatory)][ValidateSet('canary','preview','production')][string]$Target,
        [string]$DeploymentEnvironment,[string]$DeploymentAdapter,[string]$ExpectedUrl)
    $ErrorActionPreference='Stop'
    if($Target -in @('canary','preview') -and ([string]::IsNullOrWhiteSpace($DeploymentEnvironment) -or $DeploymentEnvironment -in @('prod','production'))){throw 'Preview deployment requires a named preview environment. Supply DeploymentEnvironment; production aliases are forbidden.'}
    if($Target -eq 'production' -and $DeploymentEnvironment -and $DeploymentEnvironment -notin @('prod','production')){throw 'Production deployment cannot select a preview environment. Correct Target or DeploymentEnvironment.'}
    $null=Confirm-GuideDeploymentData -DeploymentRoot $DeploymentRoot -SourceCommit $SourceCommit -Target $Target -DeploymentEnvironment $DeploymentEnvironment
    $identity=Read-GuideEvidence "$DeploymentRoot/artifact-identity.json" -Json -MaximumBytes 16777216
    if(-not $identity.ContainsKey('sourceDirty') -or $identity.sourceDirty -isnot [bool] -or $identity.sourceDirty){throw 'Deploy requires clean source evidence. Commit changes and rebuild before deploying.'}
    $environment=if($Target -eq 'production'){'production'}else{$DeploymentEnvironment}
    if($DeploymentAdapter){
        $adapter=[IO.Path]::GetFullPath($DeploymentAdapter)
        if(-not (Test-Path $adapter -PathType Leaf) -or [IO.Path]::GetExtension($adapter) -ine '.ps1'){throw 'DeploymentAdapter must identify a PowerShell script. Supply its explicit path.'}
        $result=& $adapter -ArtifactRoot "$DeploymentRoot/site" -Target $Target -Environment $environment -ExpectedUrl $ExpectedUrl
    }else{$result=Invoke-AzureGuideDeployment -ArtifactRoot "$DeploymentRoot/site" -WorkspaceRoot $WorkspaceRoot -Environment $environment}
    $url=[uri]$result.Url
    if(-not $url.IsAbsoluteUri -or $url.Scheme -cne 'https' -or $url.UserInfo -or $url.Query -or $url.Fragment){throw 'Hosting adapter returned an invalid deployment URL. Return an absolute HTTPS Url without credentials or query parameters.'}
    if($ExpectedUrl -and $url.AbsoluteUri.TrimEnd('/') -cne ([uri]$ExpectedUrl).AbsoluteUri.TrimEnd('/')){throw 'Hosting uploaded to a different URL from the configured site. Correct the environment/base URL before accepting the deployment.'}
    $record=[ordered]@{schemaVersion=1;sourceCommit=$SourceCommit;platformVersion=$identity.version;target=$Target;environment=$environment;url=$url.AbsoluteUri}
    [IO.File]::WriteAllText("$DeploymentRoot/deployment.json",($record|ConvertTo-Json))
    [pscustomobject]$record
}
