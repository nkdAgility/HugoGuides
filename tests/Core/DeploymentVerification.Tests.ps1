BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
}
Describe 'Deployed guide-site verification' {
    BeforeEach {
        $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes('expected'))).ToLowerInvariant()
        $identity=@{sourceCommit=('a'*40);version='1.2.3-Preview.4';target='preview';files=@(@{path='index.html';sha256=$hash},@{path='.well-known/open-guide-platform.json';sha256=$hash})}
        Mock Invoke-GuideHttpProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { @{StatusCode=200;Bytes=[Text.Encoding]::UTF8.GetBytes('expected')} }
    }
    It 'rejects a hosting URL inconsistent with the generated site URLs' {
        $result=Test-GuideSiteDeployment -BaseUri https://wrong.example.test/ -ExpectedBaseUri https://expected.example.test/ -Identity $identity -Attempts 1
        $result.Findings.Code | Should -Contain DEPLOYED_URL_MISMATCH
        Should -Invoke Invoke-GuideHttpProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild -Times 0 -Exactly
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
