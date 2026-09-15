function Initialize-GuideResolvedModule {
    param([string]$WorkspaceRoot,[string]$SourcePath,[string]$PlatformRoot,[string]$OutputPath,[switch]$Prepare)
    $path=Join-Path $OutputPath 'native/go.work'
    if($Prepare){
        $settings=& "$PlatformRoot/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $WorkspaceRoot -ReadSettings
        if(-not $settings -or $settings.platform.version -notmatch '^v[0-9]+(?:\.[0-9]+)?$'){return}
        if(-not (Test-Path "$PlatformRoot/platform-resolution.json")){return}
        $restored=Get-Content "$PlatformRoot/platform-resolution.json" -Raw|ConvertFrom-Json
        if($restored.mode -ne 'release'){return}
        $manifest=Get-Content "$PlatformRoot/release-manifest.json" -Raw|ConvertFrom-Json -AsHashtable
        $installed=Get-Content "$WorkspaceRoot/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json
        if($restored.version -cne $manifest.version -or $restored.sourceCommit -cne $manifest.sourceCommit){throw 'Resolved platform and native module identities differ.'}
        $relative=[IO.Path]::GetRelativePath($WorkspaceRoot,$SourcePath).Replace('\','/')
        $plan=& "$PlatformRoot/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/New-NativeHugoUpdate.ps1" -WorkspaceRoot $WorkspaceRoot -SourcePath $relative -NativeModule $manifest.nativeHugoModule -PreviousVersion $installed.nativeHugoModule.version
        if(@($plan.Files.Keys|Where-Object {$_ -notin @("$relative/go.mod","$relative/go.sum")}).Count){throw 'Floating builds require completed native-module adoption. Run Update to reconcile Hugo configuration first.'}
        [IO.Directory]::CreateDirectory((Split-Path $path))|Out-Null
        $plannedMod=[Text.Encoding]::UTF8.GetString($plan.Files["$relative/go.mod"])
        $goVersion=if($plannedMod -match '(?m)^go\s+(\S+)'){$Matches[1]}else{'1.24.5'}
        $nativeDirectory=Split-Path $path
        [IO.File]::WriteAllText("$nativeDirectory/go.mod","module openguideplatform.invalid/build-resolution`ngo $goVersion`nrequire $($manifest.nativeHugoModule.path) $($manifest.nativeHugoModule.version)`n")
        [IO.File]::WriteAllBytes("$nativeDirectory/go.sum",$plan.Files["$relative/go.sum"])
        $sourceRelative=[IO.Path]::GetRelativePath($nativeDirectory,$SourcePath).Replace('\','/')|ConvertTo-Json -Compress
        [IO.File]::WriteAllText($path,"go $goVersion`nuse (`n  $sourceRelative`n  .`n)`n")
        [ordered]@{selection=$settings.platform.version;ring=$settings.platform.ring;releaseTag=('v'+$manifest.version);sourceCommit=$manifest.sourceCommit;sha256=$manifest.packages.GuideSite.sha256;platformRoot=[IO.Path]::GetRelativePath($WorkspaceRoot,$PlatformRoot).Replace('\','/')}|ConvertTo-Json|Set-Content "$OutputPath/platform-selection.json"
        Write-Host "OGP selection $($settings.platform.version) resolved to v$($manifest.version) ($($settings.platform.ring)); native dependency prepared without changing site files."
    }
    if(Test-Path $path){
        if($env:GOFLAGS -or ($env:GOWORK -and $env:GOWORK -ne 'off')){throw 'Floating builds require unmodified GOFLAGS and GOWORK. Clear overrides so the prepared dependency is authoritative.'}
        $env:OGP_BUILD_WORKSPACE=$path
        $env:GOFLAGS='-mod=readonly'
        $env:GOWORK=$path
        $env:HUGO_MODULE_WORKSPACE=$path
    }
}
