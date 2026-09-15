BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . "$root/system/OpenGuidePlatform.PowerShell.PlatformBuild/Release/Publish-PlatformWorkflowAliases.ps1"
    function git {
        $global:LASTEXITCODE=0
        if($args -contains 'ls-remote'){return $script:refs}
        if($args -contains 'push'){$script:pushes.Add(($args -join ' '));if($script:fail){$global:LASTEXITCODE=1};return}
        throw 'Unexpected git call'
    }
}
Describe 'Version-family workflow publication' {
    BeforeEach {$script:refs=@();$script:pushes=[Collections.Generic.List[string]]::new();$script:fail=$false}
    It 'publishes only ring-specific major and minor aliases' -ForEach @(
        @{Version='1.2.3';Major='v1';Minor='v1.2'},@{Version='0.6.0-Preview.2';Major='v0-preview';Minor='v0.6-preview'}
    ) {
        Publish-PlatformWorkflowAliases -WorkspaceRoot $root -Repository example/platform -Version $Version -Commit ('a'*40)
        $script:pushes.Count|Should -Be 2
        $script:pushes[0]|Should -Match ([regex]::Escape("refs/tags/$Major"))
        $script:pushes[1]|Should -Match ([regex]::Escape("refs/tags/$Minor"))
        $script:pushes[0]|Should -Match 'force-with-lease'
    }
    It 'does not move aliases backwards when an older release is published' {
        $script:refs=@(foreach($name in @('v1','v1.2','v1.2.9')){('b'*40)+"`trefs/tags/$name"})
        Publish-PlatformWorkflowAliases -WorkspaceRoot $root -Repository example/platform -Version 1.2.3 -Commit ('a'*40)
        $script:pushes.Count|Should -Be 0
    }
    It 'fails on a lost lease rather than overwriting a concurrent publication' {
        $script:fail=$true
        {Publish-PlatformWorkflowAliases -WorkspaceRoot $root -Repository example/platform -Version 1.2.3 -Commit ('a'*40)}|Should -Throw '*changed concurrently*'
    }
}
