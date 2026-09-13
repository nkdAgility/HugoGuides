BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
}
Describe 'Prepare input freshness' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory("$workspace/site/content")|Out-Null
        [IO.Directory]::CreateDirectory("$workspace/platform")|Out-Null
        [IO.File]::WriteAllText("$workspace/site/content/_index.md",'Original wrapper')
        [IO.File]::WriteAllText("$workspace/site/hugo.production.yaml",'languages: {}')
        [IO.File]::WriteAllText("$workspace/policy.json",'{}')
        [IO.File]::WriteAllText("$workspace/overlay.json",'{}')
        $policy=Get-Content "$root/tests/Contracts/fixtures/single-guide.site-policy.json" -Raw|ConvertFrom-Json -AsHashtable
        $argsForInputs=@{WorkspaceRoot=$workspace;Policy=$policy;PolicyPath='policy.json';PlatformRoot="$workspace/platform";OverlayPath="$workspace/overlay.json";Version='0.0.0';Target='preview'}
        $before=Get-GuidePreparedInputs @argsForInputs
    }
    It 'accepts the same inputs after persisted evidence is read back' {
        $persisted=$before|ConvertTo-Json -Depth 10|ConvertFrom-Json
        { Assert-GuidePreparedInputs $persisted (Get-GuidePreparedInputs @argsForInputs) } | Should -Not -Throw
    }
    It 'rejects changed source, configuration and new downloads without changing a commit or policy' -ForEach @(@{File='site/content/_index.md'},@{File='site/hugo.production.yaml'},@{File='site/content/guide.pdf'},@{File='staticwebapp.config.json'},@{File='overlay.json'}) {
        [IO.File]::WriteAllText("$workspace/$File",'Changed after Prepare')
        { Assert-GuidePreparedInputs $before (Get-GuidePreparedInputs @argsForInputs) } | Should -Throw '*PREPARE_INPUTS_CHANGED*'
    }
    It 'rejects deleted files and runtime script changes' {
        [IO.File]::Delete("$workspace/site/content/_index.md")
        { Assert-GuidePreparedInputs $before (Get-GuidePreparedInputs @argsForInputs) } | Should -Throw '*PREPARE_INPUTS_CHANGED*'
        [IO.File]::WriteAllText("$workspace/site/content/_index.md",'Original wrapper')
        [IO.File]::WriteAllText("$workspace/platform/build.ps1",'changed runtime')
        { Assert-GuidePreparedInputs $before (Get-GuidePreparedInputs @argsForInputs) } | Should -Throw '*PREPARE_INPUTS_CHANGED*'
    }
    It 'ignores generated output but never ignores similarly named content' {
        [IO.Directory]::CreateDirectory("$workspace/site/.processing")|Out-Null
        [IO.File]::WriteAllText("$workspace/site/.processing/generated.txt",'generated')
        { Assert-GuidePreparedInputs $before (Get-GuidePreparedInputs @argsForInputs) } | Should -Not -Throw
        [IO.Directory]::CreateDirectory("$workspace/site/content/.processing")|Out-Null
        [IO.File]::WriteAllText("$workspace/site/content/.processing/guide.md",'real source')
        { Assert-GuidePreparedInputs $before (Get-GuidePreparedInputs @argsForInputs) } | Should -Throw '*PREPARE_INPUTS_CHANGED*'
    }
    It 'rejects an altered selected platform version' {
        $argsForInputs.Version='0.0.1'
        { Assert-GuidePreparedInputs $before (Get-GuidePreparedInputs @argsForInputs) } | Should -Throw '*PREPARE_INPUTS_CHANGED*'
    }
}
Describe 'Build-only tool fingerprints' {
    It 'does not require the YAML parser installed only in Prepare' {
        Mock Import-Module { throw 'Prepare-only dependency must not be loaded by Build fingerprinting.' } -ModuleName OpenGuidePlatform.PowerShell.Build
        $tools=Get-GuidePreparedBuildTools
        $tools.Tools.Keys | Should -Contain hugo
        $tools.Tools.Keys | Should -Contain go
        $tools.Tools.Keys | Should -Not -Contain powershell-yaml
        Should -Invoke Import-Module -ModuleName OpenGuidePlatform.PowerShell.Build -Times 0 -Exactly
    }
}