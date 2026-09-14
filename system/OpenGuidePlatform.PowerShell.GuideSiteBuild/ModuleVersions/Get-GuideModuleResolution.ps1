function Get-GuideModuleResolution {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PlatformRoot,[Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$Version)
    $canonical='github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides'
    $module=Join-Path $PlatformRoot 'system/OpenGuidePlatform.Hugo.Guides'
    $metadataPath=Join-Path $PlatformRoot 'platform.json'
    $mode='development'
    if(Test-Path -LiteralPath $metadataPath){
        $metadata=Get-Content -LiteralPath $metadataPath -Raw|ConvertFrom-Json
        $resolutionPath=Join-Path $PlatformRoot 'platform-resolution.json'
        if(-not (Test-Path -LiteralPath $resolutionPath)){throw 'Packaged platform requires an explicit candidate or release restoration identity.'}
        $resolution=Get-Content -LiteralPath $resolutionPath -Raw|ConvertFrom-Json
        if($resolution.schemaVersion -ne 1 -or $resolution.mode -notin @('candidate','release') -or $resolution.sourceCommit -cne $metadata.sourceCommit -or $resolution.version -cne $metadata.version -or $Version -cne $metadata.version){throw 'Platform restoration identity does not match the selected package.'}
        $mode=$resolution.mode
        if($mode -eq 'release'){
            if(-not $metadata.PSObject.Properties['nativeHugoModule']){throw 'This preview predates native module distribution; select a newer coordinated release.'}
            $native=$metadata.nativeHugoModule
            if($native.path -cne $canonical -or $native.version -cne "v$Version" -or $native.sourceCommit -cne $metadata.sourceCommit){throw 'Native module identity differs from the selected platform.'}
            $installed=Invoke-GuideGoModuleQuery $SourcePath $canonical
            if($installed.Version -cne $native.version -or $installed.PSObject.Properties['Replace']){throw 'Released builds require the coordinated native Hugo dependency without a Go replacement. Run the reviewed platform update.'}
            return [pscustomobject]@{Mode='release';ModulePath=$canonical;ModuleVersion=$native.version;Replacements=@()}
        }
    }
    # Only source development and explicitly identified pre-publication candidates
    # use packaged source. Released consumer builds must use the native module.
    [pscustomobject]@{Mode=$mode;ModulePath=$canonical;ModuleVersion=$null;Replacements=@("$canonical -> $($module.Replace('\','/'))","github.com/nkdAgility/HugoGuides/module -> $($module.Replace('\','/'))")}
}