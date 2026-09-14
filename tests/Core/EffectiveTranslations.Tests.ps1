BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1') -Force
}
Describe 'Effective translation evidence' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($workspace)|Out-Null
        Mock Get-GuideHugoConfiguration -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { @{Configuration=@{languages=@{en=@{disabled=$false};fa=@{disabled=$false};min=@{disabled=$true}}}} }
        Mock Invoke-GuideTranslationProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild {
            param($Pass)
            foreach($language in @('en','fa')){
                @{language=$language;keys=@(
                    @{key='home';value='Home'}
                    @{key='missing';value=if($Pass -eq 'placeholders'){'[i18n] missing'}else{''}}
                    @{key='fallback';value=if($Pass -eq 'placeholders' -and $language -eq 'fa'){'[i18n] fallback'}else{'English'}}
                )}
            }
        }
    }
    It 'distinguishes actual resolution, fallback and missing keys' {
        $result=Get-GuideEffectiveTranslations $workspace @('hugo.yaml') @('home','missing','fallback') $workspace '.processing/probe'
        $result.Languages.Count | Should -Be 2
        $persian=$result.Languages|Where-Object Language -EQ fa
        ($persian.Keys|Where-Object Key -EQ home).State | Should -Be available
        ($persian.Keys|Where-Object Key -EQ fallback).State | Should -Be fallback
        ($persian.Keys|Where-Object Key -EQ missing).State | Should -Be missing
        $persian.TranslationQualityAssessed | Should -BeFalse
    }
    It 'rejects missing language evidence rather than assuming fallback' {
        Mock Invoke-GuideTranslationProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { }
        {Get-GuideEffectiveTranslations $workspace @('hugo.yaml') @('home') $workspace '.processing/probe'} | Should -Throw '*unique evidence*'
    }
    It 'rejects duplicate key observations' {
        Mock Invoke-GuideTranslationProbe -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild {
            foreach($language in @('en','fa')){@{language=$language;keys=@(@{key='home';value='One'},@{key='home';value='Two'})}}
        }
        {Get-GuideEffectiveTranslations $workspace @('hugo.yaml') @('home') $workspace '.processing/probe'} | Should -Throw '*unique evidence*'
    }
    It 'refuses stale output and unsafe output paths' {
        [IO.Directory]::CreateDirectory((Join-Path $workspace '.processing/existing'))|Out-Null
        {Get-GuideEffectiveTranslations $workspace @('hugo.yaml') @('home') $workspace '.processing/existing'} | Should -Throw '*already exists*'
        {Get-GuideEffectiveTranslations $workspace @('hugo.yaml') @('home') $workspace '../outside'} | Should -Throw '*under .processing*'
    }
}