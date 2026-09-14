BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
}
Describe 'Released native dependency and candidate overlay separation' {
    BeforeEach {
        $platform=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($platform)|Out-Null
        $metadata=@{version='1.0.0-preview';sourceCommit=('a'*40);nativeHugoModule=@{path='github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides';version='v1.0.0-preview';sourceCommit=('a'*40)}}
        $resolution=@{schemaVersion=1;mode='release';version=$metadata.version;sourceCommit=$metadata.sourceCommit}
        [IO.File]::WriteAllText("$platform/platform.json",($metadata|ConvertTo-Json -Depth 5))
        [IO.File]::WriteAllText("$platform/platform-resolution.json",($resolution|ConvertTo-Json))
        $parameters=@{PlatformRoot=$platform;SourcePath=$TestDrive;Version=$metadata.version}
        Mock Invoke-GuideGoModuleQuery -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { [pscustomobject]@{Version='v1.0.0-preview'} }
    }
    It 'uses a matching native release without source replacements' {
        $result=Get-GuideModuleResolution @parameters
        $result.Mode | Should -Be release
        @($result.Replacements).Count | Should -Be 0
        $result.ModuleVersion | Should -Be 'v1.0.0-preview'
    }
    It 'refuses a different native version or a Go replacement' {
        Mock Invoke-GuideGoModuleQuery -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { [pscustomobject]@{Version='v1.0.0-preview';Replace=@{Dir='/some/local/path'}} }
        {Get-GuideModuleResolution @parameters} | Should -Throw '*without a Go replacement*'
        Mock Invoke-GuideGoModuleQuery -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild { [pscustomobject]@{Version='v0.9.0'} }
        {Get-GuideModuleResolution @parameters} | Should -Throw '*coordinated native Hugo dependency*'
    }
    It 'fails when restoration identity is absent or inconsistent' {
        $resolution.sourceCommit='b'*40
        [IO.File]::WriteAllText("$platform/platform-resolution.json",($resolution|ConvertTo-Json))
        {Get-GuideModuleResolution @parameters} | Should -Throw '*restoration identity does not match*'
        [IO.File]::Delete("$platform/platform-resolution.json")
        {Get-GuideModuleResolution @parameters} | Should -Throw '*explicit candidate or release*'
    }
    It 'uses packaged source only for an explicit pre-publication candidate' {
        $resolution.mode='candidate'
        [IO.File]::WriteAllText("$platform/platform-resolution.json",($resolution|ConvertTo-Json))
        $result=Get-GuideModuleResolution @parameters
        $result.Mode | Should -Be candidate
        @($result.Replacements).Count | Should -Be 2
        Should -Invoke Invoke-GuideGoModuleQuery -ModuleName OpenGuidePlatform.PowerShell.GuideSiteBuild -Times 0 -Exactly
    }
    It 'supports source development without a fabricated release identity' {
        [IO.File]::Delete("$platform/platform.json")
        (Get-GuideModuleResolution @parameters).Mode | Should -Be development
    }
}