function Resolve-GuideDeliveryContext {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,
        [ValidateSet('auto','local','canary','preview','production')][string]$Target='auto',
        [int]$PullRequestNumber,[string]$BaseUrl,[string]$DeploymentEnvironment,
        [string]$ConfigurationPath='.OpenGuidePlatform/delivery.yaml')
    $commit=(& git -C $WorkspaceRoot rev-parse HEAD).Trim()
    if($LASTEXITCODE -ne 0){throw 'Cannot identify the guide-site checkout. Run from a Git repository.'}
    $version=$null
    if($Target -eq 'auto'){
        $name=if($IsWindows){'dotnet-gitversion.exe'}else{'dotnet-gitversion'}
        $tool=Join-Path $WorkspaceRoot ".processing/tools/gitversion/$name"
        if(-not (Test-Path $tool)){throw 'GitVersion is missing. Run ./build.ps1 Dependencies before Prepare.'}
        $prior=$env:DOTNET_ROLL_FORWARD
        try{
            $env:DOTNET_ROLL_FORWARD='Major'
            $raw=& $tool $WorkspaceRoot /config "$WorkspaceRoot/.github/GitVersion.yml" /output json /nofetch
            if($LASTEXITCODE -ne 0){throw 'GitVersion failed. Fetch full Git history and tags, check .github/GitVersion.yml, and rerun Prepare.'}
            $version=$raw|ConvertFrom-Json
        }finally{$env:DOTNET_ROLL_FORWARD=$prior}
        if(-not $version.PSObject.Properties['PreReleaseLabel'] -or $version.SemVer -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$'){throw 'GitVersion returned incomplete version information. Check its configuration and rerun Prepare.'}
        if($version.Sha -cne $commit){throw 'GitVersion identified a different commit. Recalculate from the intended checkout.'}
        $Target=Get-GuideDeliveryRing -PreReleaseLabel $version.PreReleaseLabel
        # A PR must never select the production hosting slot, even if its source is a release branch.
        if($PullRequestNumber -gt 0){$Target='canary'}
    }
    $path=Join-Path $WorkspaceRoot $ConfigurationPath
    if(Test-Path $path){
        Import-Module powershell-yaml -MinimumVersion 0.4.12
        $configuration=Get-Content $path -Raw|ConvertFrom-Yaml
        if(-not $configuration.ContainsKey($Target)){throw "Delivery configuration has no '$Target' destination. Add it to $ConfigurationPath and rerun Prepare."}
        $destination=$configuration[$Target]
        if(-not $BaseUrl){$BaseUrl=[string]$destination['url']}
        if(-not $DeploymentEnvironment){$DeploymentEnvironment=[string]$destination['environment']}
        if("$BaseUrl$DeploymentEnvironment".Contains('{pr}')){
            $canaryEnvironment=if($PullRequestNumber -gt 0){[string]$PullRequestNumber}else{'canary'}
            $BaseUrl=$BaseUrl.Replace('{pr}',$canaryEnvironment)
            $DeploymentEnvironment=$DeploymentEnvironment.Replace('{pr}',$canaryEnvironment)
        }
    }elseif($version){throw "Delivery configuration is missing. Create $ConfigurationPath with canary, preview and production destinations."}
    if($BaseUrl){
        $uri=[uri]$BaseUrl
        if(-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http','https') -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $BaseUrl -match '[\r\n]'){throw 'Delivery URL must be an absolute HTTP(S) URL without credentials, query or fragment.'}
    }
    if($DeploymentEnvironment -match '[\r\n]' -or ($DeploymentEnvironment -and $DeploymentEnvironment -notmatch '^[A-Za-z0-9-]+$')){throw 'Deployment environment must contain only letters, numbers and hyphens.'}
    if($Target -in @('canary','preview') -and $DeploymentEnvironment -in @('prod','production')){throw 'A non-production ring cannot select the production deployment environment.'}
    if($Target -eq 'production' -and $DeploymentEnvironment -and $DeploymentEnvironment -notin @('prod','production')){throw 'Production must select the production deployment environment.'}
    [pscustomobject]@{target=$Target;sourceCommit=$commit;siteVersion=$(if($version){$version.SemVer}else{''});baseUrl=$BaseUrl;deploymentEnvironment=$DeploymentEnvironment}
}
function Get-GuideDeliveryRing {
    param([AllowEmptyString()][string]$PreReleaseLabel)
    switch($PreReleaseLabel){''{'production'} 'Preview'{'preview'} default{'canary'}}
}
