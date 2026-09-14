#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [ValidateSet('Auto','Local','Preview','Production','Path')][string]$PlatformSource='Auto',
    [string]$PlatformPath,[string]$PlatformRelease,[string]$DefaultPlatformRoot,[string]$BootstrapPath
)
$selection=$PlatformSource
$ErrorActionPreference='Stop'
if($PlatformPath -and $selection -eq 'Auto'){$selection='Path'}
if($PlatformRelease -and $selection -eq 'Auto'){$selection=if($PlatformRelease.Contains('-')){'Preview'}else{'Production'}}
if($selection -in @('Local','Path') -and $PlatformRelease){throw 'A local platform source cannot also select a release.'}
if($selection -in @('Preview','Production') -and $PlatformPath){throw 'Select a release or an explicit path, not both.'}
if($selection -eq 'Auto'){$selection=if($DefaultPlatformRoot){'Local'}else{'Locked'}}
switch($selection){
    {$_ -in @('Local','Path')} {
        $selected=if($PlatformPath){$PlatformPath}else{$DefaultPlatformRoot}
        if(-not $selected){throw 'Supply -PlatformPath for a local platform checkout or package.'}
        $selected=[IO.Path]::GetFullPath($selected)
        if(Test-Path -LiteralPath $selected -PathType Leaf){
            if([IO.Path]::GetExtension($selected) -ine '.zip'){throw 'PlatformPath must be a directory or package ZIP.'}
            $manifestPath=Join-Path (Split-Path $selected -Parent) 'release-manifest.json'
            $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
            if($manifest.archive -cne [IO.Path]::GetFileName($selected) -or (Get-FileHash $selected).Hash -ine $manifest.sha256){throw 'Explicit package identity or digest mismatch.'}
            $archive=[IO.Compression.ZipFile]::OpenRead($selected)
            $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            try{foreach($entry in $archive.Entries){if(-not $names.Add($entry.FullName) -or $entry.FullName -match '(^/|\\|:|(^|/)\.\.?(/|$))' -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'Unsafe explicit package entry.'}}}finally{$archive.Dispose()}
            $destination=Join-Path $WorkspaceRoot ('.processing/platform-path/'+[guid]::NewGuid().ToString('N'))
            Expand-Archive -LiteralPath $selected -DestinationPath $destination
            $metadata=Get-Content "$destination/platform.json" -Raw|ConvertFrom-Json
            if($metadata.sourceCommit -cne $manifest.sourceCommit -or $metadata.version -cne $manifest.version){throw 'Explicit package metadata differs.'}
            $null=& "$destination/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Confirm-PlatformPackage.ps1" -PackageRoot $destination -Manifest $manifest
            @{schemaVersion=1;mode='candidate';sourceCommit=$metadata.sourceCommit;version=$metadata.version}|ConvertTo-Json|Set-Content "$destination/platform-resolution.json"
            $selected=$destination
        }
    }
    default {
        if(-not $BootstrapPath){$BootstrapPath=Join-Path $WorkspaceRoot 'bootstrap.ps1'}
        if($selection -eq 'Locked'){$selected=& $BootstrapPath -Restore -WorkspaceRoot $WorkspaceRoot}
        else{
            $arguments=@{Resolve=$true;WorkspaceRoot=$WorkspaceRoot;Channel=if($selection -eq 'Production'){'stable'}else{'preview'}}
            if($PlatformRelease){$arguments.ReleaseTag=$PlatformRelease}
            $selected=& $BootstrapPath @arguments
        }
    }
}
if(-not (Test-Path -LiteralPath "$selected/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -PathType Leaf)){throw 'Selected platform does not contain the guide-site Build module.'}
Write-Host "Platform source: $selection; path: $selected"
return $selected
