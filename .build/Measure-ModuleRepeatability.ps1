#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ComparisonPath,[ValidatePattern('^[A-Za-z0-9_-]+$')][string]$Attempt='1')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'ModuleComparison.psm1') -Force
$root=[IO.Path]::GetFullPath($ComparisonPath)
$report=Get-Content -LiteralPath (Join-Path $root 'comparison.json') -Raw|ConvertFrom-Json
$clock=if($report.clock -is [datetime]){$report.clock.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss'Z'")}else{[string]$report.clock}
$output=Join-Path $root "repeatability-$Attempt.json"
if(Test-Path -LiteralPath $output){throw 'Repeatability evidence already exists.'}
$records=@()
foreach($build in $report.builds|Where-Object variant -EQ original){
    $name=$build.repository;$ring=$build.ring
    $snapshot=Join-Path $root "$name-original"
    $artifact=Join-Path $root "artifacts/$name/original-repeat-$Attempt/$ring"
    if(Test-Path -LiteralPath $artifact){throw 'Repeat artifact already exists.'}
    $environment=if($ring -eq 'local'){'development'}else{$ring}
    $arguments=@('--source',(Join-Path $snapshot 'site'),'--config',"hugo.yaml,hugo.$ring.yaml",'--environment',$environment,'--destination',$artifact,'--clock',$clock,'--cacheDir',(Join-Path $root 'hugo-cache'))
    $result=Invoke-CapturedTool hugo $arguments $snapshot (Join-Path $root "$name-original-repeat-$Attempt-$ring.log")
    $inventory=@(Get-ArtifactInventory $artifact)
    [IO.File]::WriteAllText((Join-Path $root "$name-original-repeat-$Attempt-$ring.files.json"),(ConvertTo-Json -InputObject $inventory -Depth 10))
    $left=Get-Content (Join-Path $root "$name-original-$ring.files.json") -Raw|ConvertFrom-Json
    $map=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach($file in $left){$map.Add($file.path,$file.sha256)}
    $differences=@(foreach($file in $inventory){
        if(-not $map.ContainsKey($file.path)){[ordered]@{path=$file.path;kind='added'}}
        elseif($map[$file.path] -cne $file.sha256){[ordered]@{path=$file.path;kind='changed'}}
        $null=$map.Remove($file.path)
    };foreach($path in $map.Keys){[ordered]@{path=$path;kind='removed'}})
    $records+= [ordered]@{repository=$name;ring=$ring;exitCode=$result.exitCode;timedOut=$result.timedOut;errors=$result.errors;files=$inventory.Count;differences=$differences}
    [IO.File]::WriteAllText($output,(@{scope='Same archived source/module paths, same clock/cache/toolchain, new artifact directory. No fields ignored.';candidateCommit=$report.candidateCommit;records=$records}|ConvertTo-Json -Depth 20))
    Write-Host "$name $ring : exit=$($result.exitCode) differences=$($differences.Count)"
}
if(@($records|Where-Object {$_.exitCode -ne 0 -or $_.timedOut -or $_.errors}).Count){throw 'Repeatability evidence contains failed builds.'}