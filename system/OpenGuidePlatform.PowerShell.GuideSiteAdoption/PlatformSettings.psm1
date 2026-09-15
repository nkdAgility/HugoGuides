# User-owned settings migration. Returned bytes join the adoption transaction.
function New-GuideSettingsPlan {
    param([string]$WorkspaceRoot,[string]$PackageRoot,[string]$SourcePath,$Previous,$Manifest)
    Import-Module powershell-yaml -MinimumVersion 0.4.12 -ErrorAction Stop
    $relative='.OpenGuidePlatform/settings.yaml';$path=Join-Path $WorkspaceRoot $relative
    $legacy='.OpenGuidePlatform/delivery.yaml';$legacyPath=Join-Path $WorkspaceRoot $legacy
    $expected=[ordered]@{};$retired=@();$original=$null
    foreach($name in @($relative,$legacy)){
        $file=Join-Path $WorkspaceRoot $name
        if(Test-Path $file){
            if((Get-Item $file).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Linked settings are unsupported: $name"}
            $expected[$name]=(Get-FileHash $file).Hash.ToLowerInvariant()
        }else{$expected[$name]=$null}
    }
    if(Test-Path $path){
        $original=[IO.File]::ReadAllBytes($path)
        $settings=& "$PSScriptRoot/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $WorkspaceRoot -ReadSettings
    }else{
        $selected=if($Previous){$Previous.releaseTag}else{'v'+$Manifest.version}
        $ring=if($Previous){if($Previous.release.channel -eq 'preview'){'preview'}else{'production'}}else{if($Manifest.channel -eq 'preview'){'preview'}else{'production'}}
        $source=if($Previous -and $Previous.ContainsKey('sourcePath')){$Previous.sourcePath}else{$SourcePath}
        $settings=[ordered]@{platform=[ordered]@{version=$selected;ring=$ring};site=[ordered]@{source=$source};delivery=[ordered]@{}}
    }
    $changed=$false
    if(Test-Path $legacyPath){
        $delivery=Get-Content $legacyPath -Raw|ConvertFrom-Yaml
        if($delivery -isnot [Collections.IDictionary]){throw 'Legacy delivery.yaml must contain delivery mappings.'}
        foreach($ring in $delivery.Keys){
            if(-not $settings.delivery.Contains($ring)){$settings.delivery[$ring]=$delivery[$ring];$changed=$true;continue}
            foreach($key in $delivery[$ring].Keys){
                if($settings.delivery[$ring].Contains($key) -and $settings.delivery[$ring][$key] -cne $delivery[$ring][$key]){throw "Conflicting delivery settings for $ring.$key. Reconcile settings.yaml and delivery.yaml before updating."}
                if(-not $settings.delivery[$ring].Contains($key)){$changed=$true}
                $settings.delivery[$ring][$key]=$delivery[$ring][$key]
            }
        }
        $retired=@($legacy)
    }
    $choicePath=Join-Path $PackageRoot 'platform-selection.json'
    if(Test-Path $choicePath){
        $choice=Get-Content $choicePath -Raw|ConvertFrom-Json
        if($settings.platform.version -cne $choice.version -or $settings.platform.ring -cne $choice.ring){$changed=$true}
        $settings.platform.version=$choice.version;$settings.platform.ring=$choice.ring
    }elseif($Previous -and -not (Test-Path $path)){
        # An explicit legacy Update installs the selected release, retaining exact pin semantics.
        $settings.platform.version='v'+$Manifest.version
        $settings.platform.ring=if($Manifest.channel -eq 'preview'){'preview'}else{'production'}
    }
    $workflowReference=[string]$settings.platform.version
    if($workflowReference -match '^v[0-9]+(?:\.[0-9]+)?$' -and $settings.platform.ring -eq 'preview'){$workflowReference+='-preview'}
    $bytes=if($null -ne $original -and -not $changed){$original}else{[Text.Encoding]::UTF8.GetBytes(($settings|ConvertTo-Yaml))}
    [pscustomobject]@{Settings=$settings;Files=[ordered]@{$relative=$bytes};ExpectedHashes=$expected;Retired=$retired;WorkflowReference=$workflowReference}
}
Export-ModuleMember -Function New-GuideSettingsPlan
