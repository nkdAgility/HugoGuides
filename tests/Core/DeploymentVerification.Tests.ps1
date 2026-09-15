BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
}
Describe 'Hosting identity redirects' {
    It 'follows only the exact configured public identity URL' {
        Mock Invoke-WebRequest -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild {
            param($Uri)
            if($Uri -eq 'https://provider.example.test/.well-known/open-guide-platform.json'){
                Write-Error 'The maximum redirection count has been exceeded.' -ErrorAction SilentlyContinue
                return @{StatusCode=301;Headers=@{Location=@('https://public.example.test/.well-known/open-guide-platform.json')}}
            }
            @{StatusCode=200;RawContentStream=[IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes('identity'))}
        }
        $result=& (Get-Module OpenGuidePlatform.PowerShell.GuideSiteBuild) { Invoke-GuideHttpProbe -Uri https://provider.example.test/.well-known/open-guide-platform.json -ExpectedRedirectUri https://public.example.test/.well-known/open-guide-platform.json }
        $result.StatusCode | Should -Be 200
        [Text.Encoding]::UTF8.GetString($result.Bytes) | Should -Be identity
        Should -Invoke Invoke-WebRequest -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild -Times 2 -Exactly
    }
    It 'rejects redirects to another host or path' -ForEach @('https://other.example.test/.well-known/open-guide-platform.json','https://public.example.test/fallback') {
        $redirect=$_
        Mock Invoke-WebRequest -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { @{StatusCode=302;Headers=@{Location=@($redirect)}} }
        {& (Get-Module OpenGuidePlatform.PowerShell.GuideSiteBuild) { Invoke-GuideHttpProbe -Uri https://provider.example.test/.well-known/open-guide-platform.json -ExpectedRedirectUri https://public.example.test/.well-known/open-guide-platform.json }} | Should -Throw '*unexpected URL*'
        Should -Invoke Invoke-WebRequest -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild -Times 1 -Exactly
    }
    It 'fails when the provider cannot be reached' {
        Mock Invoke-WebRequest -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { $null }
        {& (Get-Module OpenGuidePlatform.PowerShell.GuideSiteBuild) { Invoke-GuideHttpProbe -Uri https://provider.example.test/ }} | Should -Throw '*HTTP probe failed*'
    }
}
Describe 'Deployed guide-site verification' {
    BeforeEach {
        $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes('expected'))).ToLowerInvariant()
        $identity=@{sourceCommit=('a'*40);version='1.2.3-Preview.4';target='preview';files=@(@{path='index.html';sha256=$hash},@{path='.well-known/open-guide-platform.json';sha256=$hash})}
        Mock Invoke-GuideHttpProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { @{StatusCode=200;Bytes=[Text.Encoding]::UTF8.GetBytes('expected')} }
    }
    It 'verifies the provider identity and the custom domain content separately' {
        $result=Test-GuideSiteDeployment -BaseUri https://provider.example.test/ -ExpectedBaseUri https://public.example.test/ -Identity $identity -Attempts 1
        $result.Outcome | Should -Be pass
        $result.Url | Should -Be 'https://public.example.test/'
        Should -Invoke Invoke-GuideHttpProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://provider.example.test/.well-known/open-guide-platform.json' -and $ExpectedRedirectUri -eq 'https://public.example.test/.well-known/open-guide-platform.json' }
        Should -Invoke Invoke-GuideHttpProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://public.example.test/' }
    }
    It 'rejects stale content at either the provider or the custom domain' -ForEach @('provider','public') {
        $badHost=$_
        Mock Invoke-GuideHttpProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild {
            param($Uri)
            @{StatusCode=200;Bytes=[Text.Encoding]::UTF8.GetBytes($(if($Uri.Contains($badHost)){'stale'}else{'expected'}))}
        }
        $result=Test-GuideSiteDeployment -BaseUri https://provider.example.test/ -ExpectedBaseUri https://public.example.test/ -Identity $identity -Attempts 1
        $result.Outcome | Should -Be fail
        if($badHost -eq 'provider'){$result.Findings.Code | Should -Contain HOSTING_IDENTITY_MISMATCH}
        else{$result.Findings.Code | Should -Contain DEPLOYED_RESOURCE_MISMATCH}
    }
    It 'accepts responses matching the validated artifact' {
        (Test-GuideSiteDeployment -BaseUri https://example.test/ -Identity $identity -Attempts 1).Outcome | Should -Be pass
    }
    It 'rejects a different deployed identity even when HTTP is successful' {
        Mock Invoke-GuideHttpProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild {
            param($Uri)
            @{StatusCode=200;Bytes=[Text.Encoding]::UTF8.GetBytes($(if($Uri.EndsWith('open-guide-platform.json')){'other deployment'}else{'expected'}))}
        }
        $result=Test-GuideSiteDeployment -BaseUri https://example.test/ -Identity $identity -Attempts 1
        $result.Outcome | Should -Be fail
        $result.Findings.Path | Should -Contain '/.well-known/open-guide-platform.json'
    }
    It 'rejects a successful HTTP fallback page with wrong content' {
        Mock Invoke-GuideHttpProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { @{StatusCode=200;Bytes=[Text.Encoding]::UTF8.GetBytes('<html>Not found</html>')} }
        (Test-GuideSiteDeployment -BaseUri https://example.test/ -Identity $identity -Attempts 1).Outcome | Should -Be fail
    }
    It 'rejects a prohibited language route returning success' {
        $result=Test-GuideSiteDeployment -BaseUri https://example.test/ -Identity $identity -ForbiddenPaths @('min') -Attempts 1
        $result.Findings.Code | Should -Contain DEPLOYED_EXCLUSION_UNVERIFIED
    }
    It 'rejects an excluded PDF outside language prefixes and requests its exact file URL' {
        $result=Test-GuideSiteDeployment -BaseUri https://example.test/ -Identity $identity -ForbiddenDownloads @('downloads/guide.min.pdf') -Attempts 1
        $result.Findings.Code | Should -Contain DEPLOYED_DOWNLOAD_EXCLUSION_UNVERIFIED
        Should -Invoke Invoke-GuideHttpProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild -ParameterFilter { $Uri -eq 'https://example.test/downloads/guide.min.pdf' } -Times 1 -Exactly
    }
    It 'verifies PDF responses as well as required pages' {
        $identity.files+=@{path='guide.pdf';sha256=$hash}
        Mock Invoke-GuideHttpProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild {
            param($Uri)
            @{StatusCode=if($Uri.EndsWith('.pdf')){404}else{200};Bytes=[Text.Encoding]::UTF8.GetBytes('expected')}
        }
        $result=Test-GuideSiteDeployment -BaseUri https://example.test/ -Identity $identity -Attempts 1
        $result.Findings.Path | Should -Contain '/guide.pdf'
    }
}
