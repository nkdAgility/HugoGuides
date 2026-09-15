BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
}
Describe 'Floating native module evidence' {
    It 'uses the exact native release in Go and Hugo without changing source files' -Skip:($env:OGP_TEST_FLOATING_NATIVE -ne '1') {
        $workspace=Join-Path $TestDrive 'native-resolution'
        $platform=Join-Path $workspace '.processing/platform'
        $source=Join-Path $workspace 'site';$output=Join-Path $workspace '.processing/evidence'
        foreach($path in @("$platform/system",$source,$output,"$workspace/.OpenGuidePlatform")){New-Item -ItemType Directory $path -Force|Out-Null}
        foreach($component in @('OpenGuidePlatform.PowerShell.Core','OpenGuidePlatform.PowerShell.GuideSiteAdoption')){Copy-Item "$root/system/$component" "$platform/system" -Recurse}
        $module='github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides'
        $commit='8a59451437d7d1bcc20d32ea79dd7680e804c9c8'
        $native=@{path=$module;version='v0.5.6';sourceCommit=$commit}
        @{schemaVersion=1;mode='release';version='0.5.6';sourceCommit=$commit}|ConvertTo-Json|Set-Content "$platform/platform-resolution.json"
        @{version='0.5.6';sourceCommit=$commit;nativeHugoModule=$native}|ConvertTo-Json -Depth 8|Set-Content "$platform/platform.json"
        @{version='0.5.6';sourceCommit=$commit;nativeHugoModule=$native;packages=@{GuideSite=@{sha256=('a'*64)}}}|ConvertTo-Json -Depth 8|Set-Content "$platform/release-manifest.json"
        @{nativeHugoModule=@{version='v0.5.5'}}|ConvertTo-Json|Set-Content "$workspace/.OpenGuidePlatform/installation.json"
        Set-Content "$workspace/.OpenGuidePlatform/settings.yaml" "platform:`n  version: v0`n  ring: production`nsite:`n  source: site`ndelivery: {}"
        Set-Content "$source/go.mod" "module example.test/site`ngo 1.24.5`nrequire $module v0.5.5"
        Set-Content "$source/hugo.yaml" "baseURL: https://example.test/`nmodule:`n  imports:`n    - path: $module"
        $before=(Get-FileHash "$source/go.mod").Hash
        $saved=@{GOFLAGS=$env:GOFLAGS;GOWORK=$env:GOWORK;OGP_BUILD_WORKSPACE=$env:OGP_BUILD_WORKSPACE;HUGO_MODULE_WORKSPACE=$env:HUGO_MODULE_WORKSPACE}
        try {
            $env:GOFLAGS=$null;$env:GOWORK=$null;$env:OGP_BUILD_WORKSPACE=$null;$env:HUGO_MODULE_WORKSPACE=$null
            Initialize-GuideResolvedModule -WorkspaceRoot $workspace -SourcePath $source -PlatformRoot $platform -OutputPath $output -Prepare
            (Get-GuideModuleResolution -PlatformRoot $platform -SourcePath $source -Version 0.5.6).ModuleVersion|Should -Be v0.5.6
            $graph=& hugo mod graph --source $source 2>&1
            $LASTEXITCODE|Should -Be 0
            ($graph -join "`n")|Should -Match ([regex]::Escape("$module@v0.5.6"))
            (Get-FileHash "$source/go.mod").Hash|Should -Be $before
            Test-Path "$source/go.sum"|Should -BeFalse
            $policy=@{wrapper=@{sourcePath='site';requiredFiles=@()};guides=@()}
            $fingerprint=Get-GuidePreparedInputs -WorkspaceRoot $workspace -Policy $policy -PolicyPath '.processing/evidence/discovered-site.json' -PlatformRoot $platform -OverlayPath "$output/candidate-platform.json" -Version 0.5.6 -Target preview
            $env:GOFLAGS=$null;$env:GOWORK=$null;$env:OGP_BUILD_WORKSPACE=$null;$env:HUGO_MODULE_WORKSPACE=$null
            $relocated=Join-Path $TestDrive 'another-runner'
            Copy-Item $workspace $relocated -Recurse
            $workspace=$relocated;$source=Join-Path $workspace 'site';$platform=Join-Path $workspace '.processing/platform';$output=Join-Path $workspace '.processing/evidence'
            Initialize-GuideResolvedModule -WorkspaceRoot $workspace -SourcePath $source -PlatformRoot $platform -OutputPath $output
            (Get-GuideModuleResolution -PlatformRoot $platform -SourcePath $source -Version 0.5.6).ModuleVersion|Should -Be v0.5.6
            $resumed=Get-GuidePreparedInputs -WorkspaceRoot $workspace -Policy $policy -PolicyPath '.processing/evidence/discovered-site.json' -PlatformRoot $platform -OverlayPath "$output/candidate-platform.json" -Version 0.5.6 -Target preview
            $resumed.Sha256|Should -Be $fingerprint.Sha256
        }finally{
            foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name])}
            Get-Module -All|Where-Object {$_.Path -and $_.Path.StartsWith($TestDrive,[StringComparison]::OrdinalIgnoreCase)}|Remove-Module -Force
        }
    }
}
