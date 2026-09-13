#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselinePath,
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$CandidateRef='HEAD',
    [string]$Clock='2026-09-13T00:00:00Z'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $PSScriptRoot 'ModuleComparison.psm1') -Force
$repositories=Split-Path $root -Parent
if($OutputPath -notmatch '^\.processing/[A-Za-z0-9_-]+$'){throw 'Use a fresh direct child of .processing for comparison output.'}
$output=Join-Path $root $OutputPath
if(Test-Path -LiteralPath $output){throw 'Comparison output already exists.'}
$cursor=[IO.Path]::GetFullPath($output)
while($cursor){if(Test-Path -LiteralPath $cursor){if((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked comparison output is not supported.'}};$cursor=[IO.Path]::GetDirectoryName($cursor)}
$baseline=Get-Content -LiteralPath (Join-Path $BaselinePath 'baseline.json') -Raw|ConvertFrom-Json
$candidate=(& git -C $root rev-parse "$CandidateRef^{commit}").Trim()
if($LASTEXITCODE -ne 0){throw 'Cannot resolve candidate commit.'}
$original=@($baseline.repositories|Where-Object repository -EQ HugoGuides)[0].commit
[IO.Directory]::CreateDirectory($output)|Out-Null

Export-SourceArchive $root $original (Join-Path $output 'original-module') 'module'
Export-SourceArchive $root $candidate (Join-Path $output 'relocated-module') 'system/OpenGuidePlatform.Hugo.Guides'
$modulePaths=@{
    original=(Join-Path $output 'original-module/module')
    relocated=(Join-Path $output 'relocated-module/system/OpenGuidePlatform.Hugo.Guides')
}


$report=[ordered]@{
    schemaVersion=1;candidateCommit=$candidate;originalModuleCommit=$original;clock=$Clock
    hugo=(& hugo version|Out-String).Trim();go=(& go version|Out-String).Trim()
    scope='Isolated raw Hugo builds: pinned dependency, original module and relocated module. No consumer checkout edits or deployment. Exact byte comparison; no ignored output fields.'
    builds=@();comparisons=@()
}
foreach($name in @('KanbanGuides','the-safe-delusion','ScrumGuide-ExpansionPack')){
    $commit=@($baseline.repositories|Where-Object repository -EQ $name)[0].commit
    foreach($variant in @('pinned','original','relocated')){
        $snapshot=Join-Path $output "$name-$variant"
        Export-SourceArchive (Join-Path $repositories $name) $commit $snapshot $null
        $site=Join-Path $snapshot 'site'
        if($variant -ne 'pinned'){
            $replacement="github.com/nkdAgility/HugoGuides/module=$($modulePaths[$variant])"
            $result=Invoke-CapturedTool go @('mod','edit',"-replace=$replacement") $site (Join-Path $output "$name-$variant-go.log")
            if($result.exitCode -ne 0 -or $result.timedOut){throw 'Isolated module replacement failed.'}
        }
        foreach($ring in @('local','preview','production')){
            $environment=if($ring -eq 'local'){'development'}else{$ring}
            $artifact=Join-Path $output "artifacts/$name/$variant/$ring"
            $log=Join-Path $output "$name-$variant-$ring.log"
            $arguments=@('--source',$site,'--config',"hugo.yaml,hugo.$ring.yaml",'--environment',$environment,'--destination',$artifact,'--clock',$Clock,'--cacheDir',(Join-Path $output 'hugo-cache'))
            $result=Invoke-CapturedTool hugo $arguments $snapshot $log
            $inventory=@(Get-ArtifactInventory $artifact)
            [IO.File]::WriteAllText((Join-Path $output "$name-$variant-$ring.files.json"),(ConvertTo-Json -InputObject $inventory -Depth 10))
            $record=[ordered]@{repository=$name;sourceCommit=$commit;variant=$variant;ring=$ring;exitCode=$result.exitCode;timedOut=$result.timedOut;errors=$result.errors;warnings=$result.warnings;files=$inventory.Count;passed=($result.exitCode -eq 0 -and -not $result.timedOut -and $result.errors -eq 0)}
            $report.builds+= $record
            [IO.File]::WriteAllText((Join-Path $output 'comparison.json'),($report|ConvertTo-Json -Depth 20))
            Write-Host "$name $variant $ring : passed=$($record.passed) files=$($record.files)"
        }
    }
    foreach($ring in @('local','preview','production')){
        foreach($pair in @(@{before='pinned';after='original';purpose='Dependency version differences'},@{before='original';after='relocated';purpose='Mechanical relocation equivalence'})){
            $left=@(Get-Content (Join-Path $output "$name-$($pair.before)-$ring.files.json") -Raw|ConvertFrom-Json)
            $right=@(Get-Content (Join-Path $output "$name-$($pair.after)-$ring.files.json") -Raw|ConvertFrom-Json)
            $map=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
            foreach($file in $left){$map.Add($file.path,$file.sha256)}
            $differences=@(foreach($file in $right){
                if(-not $map.ContainsKey($file.path)){[ordered]@{path=$file.path;kind='added'}}
                elseif($map[$file.path] -cne $file.sha256){[ordered]@{path=$file.path;kind='changed'}}
                $null=$map.Remove($file.path)
            };foreach($path in $map.Keys){[ordered]@{path=$path;kind='removed'}})
            $builds=@($report.builds|Where-Object {$_.repository -eq $name -and $_.ring -eq $ring -and $_.variant -in @($pair.before,$pair.after)})
            $report.comparisons+= [ordered]@{repository=$name;ring=$ring;before=$pair.before;after=$pair.after;purpose=$pair.purpose;outcome=if(@($builds|Where-Object {-not $_.passed}).Count){'blocked'}elseif($differences.Count){'different'}else{'identical'};differences=$differences}
        }
    }
    [IO.File]::WriteAllText((Join-Path $output 'comparison.json'),($report|ConvertTo-Json -Depth 20))
}
$report.comparisons|ForEach-Object {Write-Host "$($_.repository) $($_.ring) $($_.purpose): $($_.outcome) ($($_.differences.Count) differences)"}
if(@($report.builds|Where-Object {-not $_.passed}).Count){throw 'Comparison includes failed builds; inspect comparison.json and logs.'}