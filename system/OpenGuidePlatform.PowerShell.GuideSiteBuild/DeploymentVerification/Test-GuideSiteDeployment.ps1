function Invoke-GuideHttpProbe {
    param([string]$Uri,[string]$ExpectedRedirectUri)
    # PowerShell also emits a non-terminating error for a blocked redirect.
    $response=Invoke-WebRequest -Uri $Uri -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 20 -ErrorAction SilentlyContinue -ErrorVariable probeErrors
    if(-not $response){throw "HTTP probe failed: $probeErrors"}
    if($ExpectedRedirectUri -and [int]$response.StatusCode -in @(301,302,303,307,308)){
        $location=[uri]::new([uri]$Uri,[string]($response.Headers.Location | Select-Object -First 1))
        if($location.AbsoluteUri -cne $ExpectedRedirectUri){throw 'Hosting redirected to an unexpected URL.'}
        $response=Invoke-WebRequest -Uri $ExpectedRedirectUri -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 20
    }
    [pscustomobject]@{StatusCode=[int]$response.StatusCode;Bytes=$response.RawContentStream.ToArray()}
}
function Test-GuideSiteDeployment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$BaseUri,
        [Parameter(Mandatory)]$Identity,[uri]$ExpectedBaseUri,
        [string[]]$RequiredRoutes=@('/'),
        [string[]]$ForbiddenPaths=@(),
        [string[]]$ForbiddenDownloads=@(),
        [ValidateRange(1,10)][int]$Attempts=5
    )
    if($BaseUri.Scheme -notin @('https','http') -or $BaseUri.Query -or $BaseUri.Fragment -or $BaseUri.UserInfo){throw 'Supply an HTTP(S) deployment base URL without credentials, query or fragment.'}
    $hostingUri=$BaseUri
    if($ExpectedBaseUri){
        if(-not $ExpectedBaseUri.IsAbsoluteUri -or $ExpectedBaseUri.Scheme -notin @('https','http') -or $ExpectedBaseUri.Query -or $ExpectedBaseUri.Fragment -or $ExpectedBaseUri.UserInfo){throw 'Supply an HTTP(S) public base URL without credentials, query or fragment.'}
        $BaseUri=$ExpectedBaseUri
    }
    $checks=@(@{Route='/.well-known/open-guide-platform.json';Path='.well-known/open-guide-platform.json'})
    foreach($route in $RequiredRoutes){
        $candidates=@(Get-GuideArtifactRouteCandidates $route)
        $matches=@($Identity.files|Where-Object { $_.path -cin $candidates })
        if($matches.Count -ne 1){throw "Cannot establish deployed route identity: $route"}
        $checks+=@{Route=$route;Path=$matches[0].path}
    }
    foreach($pdf in $Identity.files|Where-Object path -Match '\.pdf$'){
        $checks+=@{Route='/'+(($pdf.path.Split('/')|ForEach-Object {[uri]::EscapeDataString($_)}) -join '/');Path=$pdf.path}
    }
    for($attempt=1;$attempt -le $Attempts;$attempt++){
        $findings=[Collections.Generic.List[object]]::new()
        if($hostingUri.AbsoluteUri.TrimEnd('/') -cne $BaseUri.AbsoluteUri.TrimEnd('/')){
            try{
                $path='/.well-known/open-guide-platform.json'
                $expected=@($Identity.files|Where-Object path -CEQ $path.TrimStart('/'))
                if($expected.Count -ne 1){throw 'Missing expected deployment identity.'}
                $response=Invoke-GuideHttpProbe -Uri ($hostingUri.AbsoluteUri.TrimEnd('/')+$path) -ExpectedRedirectUri ($BaseUri.AbsoluteUri.TrimEnd('/')+$path)
                if($response.StatusCode -ne 200){throw "HTTP $($response.StatusCode)"}
                $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$response.Bytes)).ToLowerInvariant()
                if($hash -cne $expected[0].sha256){throw 'Hosting identity does not match the validated artifact.'}
            }catch{$findings.Add(@{Code='HOSTING_IDENTITY_MISMATCH';Path=$hostingUri.AbsoluteUri;Message=$_.Exception.Message})}
        }
        foreach($check in $checks){
            try{
                $expected=@($Identity.files|Where-Object path -CEQ $check.Path)
                if($expected.Count -ne 1){throw "Missing expected identity for $($check.Path)"}
                $uri=[uri]::new($BaseUri.AbsoluteUri.TrimEnd('/')+$check.Route)
                $response=Invoke-GuideHttpProbe $uri.AbsoluteUri
                if($response.StatusCode -ne 200){throw "HTTP $($response.StatusCode)"}
                $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$response.Bytes)).ToLowerInvariant()
                if($hash -cne $expected[0].sha256){throw 'Response bytes do not match the validated artifact (wrong deployment or fallback page).'}
            }catch{$findings.Add(@{Code='DEPLOYED_RESOURCE_MISMATCH';Path=$check.Route;Message=$_.Exception.Message})}
        }
        foreach($path in $ForbiddenPaths){
            try{
                $response=Invoke-GuideHttpProbe ($BaseUri.AbsoluteUri.TrimEnd('/')+'/'+$path.Trim('/')+'/')
                if($response.StatusCode -notin @(404,410)){throw "Prohibited route returned HTTP $($response.StatusCode)."}
            }catch{$findings.Add(@{Code='DEPLOYED_EXCLUSION_UNVERIFIED';Path=$path;Message=$_.Exception.Message})}
        }
        foreach($path in $ForbiddenDownloads){
            try{
                $uri=$BaseUri.AbsoluteUri.TrimEnd('/')+'/'+(($path.Split('/')|ForEach-Object {[uri]::EscapeDataString($_)}) -join '/')
                $response=Invoke-GuideHttpProbe $uri
                if($response.StatusCode -notin @(404,410)){throw "Prohibited download returned HTTP $($response.StatusCode)."}
            }catch{$findings.Add(@{Code='DEPLOYED_DOWNLOAD_EXCLUSION_UNVERIFIED';Path=$path;Message=$_.Exception.Message})}
        }
        if($findings.Count -eq 0){return [pscustomobject]@{Outcome='pass';SourceCommit=$Identity.sourceCommit;PlatformVersion=$Identity.version;Target=$Identity.target;Url=$BaseUri.AbsoluteUri;Attempts=$attempt;Findings=@()}}
        if($attempt -lt $Attempts){Start-Sleep -Seconds 5}
    }
    [pscustomobject]@{Outcome='fail';SourceCommit=$Identity.sourceCommit;PlatformVersion=$Identity.version;Target=$Identity.target;Url=$BaseUri.AbsoluteUri;Attempts=$Attempts;Findings=$findings.ToArray()}
}
