function Resolve-GuideBrowserToolCache {
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$LockSha256)
    $cache=Resolve-GuideWorkspacePath $WorkspaceRoot ".processing/browser-tools/$LockSha256"
    # Leave headroom for Chromium's executable suffix under Windows process APIs.
    if($IsWindows -and $cache.Length + 100 -gt 240){
        $key=[IO.Path]::GetFullPath($WorkspaceRoot).ToLowerInvariant()+':'+$LockSha256
        $digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($key))).ToLowerInvariant()
        $cache=Resolve-GuideWorkspacePath ([IO.Path]::GetTempPath()) ("ogp-browser/"+$digest.Substring(0,32))
        if($cache.Length + 100 -gt 260){throw 'The Windows temporary path is too long for Chromium. Use a shorter temporary directory.'}
    }
    $cache
}

function Test-GuideRuntimeAnchors {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$ArtifactRoot,[Parameter(Mandatory)][uri]$BaseUri,[Parameter(Mandatory)][string]$IdentityPath,[Parameter(Mandatory)][string]$OutputPath,[object[]]$Anchors=@())
    $ErrorActionPreference='Stop'
    $artifactIdentity=Get-Content -LiteralPath $IdentityPath -Raw|ConvertFrom-Json
    $null=Test-GuideArtifactIdentity -ArtifactRoot $ArtifactRoot -Identity $artifactIdentity -ExpectedTarget $artifactIdentity.target -ExpectedSourceCommit $artifactIdentity.sourceCommit
    $identity=(Get-FileHash -LiteralPath $IdentityPath).Hash.ToLowerInvariant()
    if(-not $Anchors -or -not $Anchors.Count){return [pscustomobject]@{schemaVersion=1;outcome='not-required';artifactIdentitySha256=$identity;observations=@()}}
    $evidence=Resolve-GuideWorkspacePath $WorkspaceRoot $OutputPath
    [IO.Directory]::CreateDirectory($evidence)|Out-Null
    $lock=(Get-FileHash "$PSScriptRoot/package-lock.json").Hash.ToLowerInvariant()
    $cache=Resolve-GuideBrowserToolCache -WorkspaceRoot $WorkspaceRoot -LockSha256 $lock
    [IO.File]::WriteAllText("$evidence/browser-cache.log",$cache)
    [IO.Directory]::CreateDirectory($cache)|Out-Null
    foreach($name in @('package.json','package-lock.json')){[IO.File]::Copy("$PSScriptRoot/$name","$cache/$name",$true)}
    if(-not (Test-Path "$cache/node_modules/playwright/cli.js")){
        $install=@(& npm ci --ignore-scripts --prefix $cache 2>&1)
        [IO.File]::WriteAllLines("$evidence/browser-install.log",[string[]]$install)
        if($LASTEXITCODE -ne 0){throw 'Browser validation dependencies could not be restored. See browser-install.log; Node.js and npm are required.'}
    }
    $previous=$env:PLAYWRIGHT_BROWSERS_PATH
    try{
        $env:PLAYWRIGHT_BROWSERS_PATH=Join-Path $cache 'browsers'
        $install=@(& node "$cache/node_modules/playwright/cli.js" install chromium 2>&1)
        [IO.File]::WriteAllLines("$evidence/browser-download.log",[string[]]$install)
        if($LASTEXITCODE -ne 0){throw 'Chromium could not be restored. See browser-download.log.'}
        $request=@{artifactRoot=$ArtifactRoot;baseUri=$BaseUri.AbsoluteUri;artifactIdentitySha256=$identity;anchors=@($Anchors)}
        [IO.File]::WriteAllText("$evidence/runtime-request.json",($request|ConvertTo-Json -Depth 10))
        $raw=@(& node "$PSScriptRoot/Measure-GuideRuntimeAnchors.cjs" "$evidence/runtime-request.json" $cache 2> "$evidence/browser-errors.log")
        $browserExit=$LASTEXITCODE
        [IO.File]::WriteAllLines("$evidence/browser-output.log",[string[]]$raw)
        if($browserExit -ne 0){throw 'Runtime anchor browser check failed. See browser-output.log and browser-errors.log.'}
        $result=($raw -join "`n")|ConvertFrom-Json
        if($result.artifactIdentitySha256 -cne $identity -or $result.schemaVersion -ne 1 -or @($result.observations).Count -ne $Anchors.Count){throw 'Runtime anchor evidence does not match this artifact.'}
        $null=Test-GuideArtifactIdentity -ArtifactRoot $ArtifactRoot -Identity $artifactIdentity -ExpectedTarget $artifactIdentity.target -ExpectedSourceCommit $artifactIdentity.sourceCommit
        if((Get-FileHash -LiteralPath $IdentityPath).Hash.ToLowerInvariant() -cne $identity){throw 'Artifact identity changed during browser validation.'}
        return $result
    }finally{$env:PLAYWRIGHT_BROWSERS_PATH=$previous}
}

function Resolve-GuideRuntimeNavigation {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Navigation,[Parameter(Mandatory)]$Runtime)
    $resolved=@($Runtime.observations|Where-Object exists)
    $remaining=@($Navigation.Findings|Where-Object {
        $finding=$_
        if($finding.Code -cne 'INTERNAL_ANCHOR_MISSING'){return $true}
        -not @($resolved|Where-Object {
            $page=$_.route.TrimStart('/')
            if(-not $page -or $page.EndsWith('/')){$page+='index.html'}
            $page -ceq $finding.TargetPage -and $_.fragment -ceq $finding.Fragment
        }).Count
    })
    [pscustomobject]@{Outcome=if($remaining.Count){'fail'}else{'pass'};Pages=$Navigation.Pages;Links=$Navigation.Links;Anchors=$Navigation.Anchors;Findings=$remaining}
}
