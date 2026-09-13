#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ComparisonPath,[ValidatePattern('^[A-Za-z0-9_-]+\.json$')][string]$OutputName='difference-classification.json')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($ComparisonPath)
$report=Get-Content -LiteralPath (Join-Path $root 'comparison.json') -Raw|ConvertFrom-Json
$output=Join-Path $root $OutputName
if(Test-Path -LiteralPath $output){throw 'Classification already exists; preserve earlier evidence.'}
$records=foreach($comparison in $report.comparisons){
    $differences=foreach($difference in $comparison.differences){
        $classification=$difference.kind
        if($difference.kind -eq 'changed'){
            $leftPath=Join-Path $root "artifacts/$($comparison.repository)/$($comparison.before)/$($comparison.ring)/$($difference.path)"
            $rightPath=Join-Path $root "artifacts/$($comparison.repository)/$($comparison.after)/$($comparison.ring)/$($difference.path)"
            if([IO.Path]::GetExtension($difference.path) -in @('.html','.json','.xml','.css','.js')){
                $left=[IO.File]::ReadAllText($leftPath);$right=[IO.File]::ReadAllText($rightPath)
                $leftPrefix=Join-Path $root "$($comparison.repository)-$($comparison.before)"
                $rightPrefix=Join-Path $root "$($comparison.repository)-$($comparison.after)"
                foreach($prefix in @($leftPrefix,$leftPrefix.Replace('\','/'))){$left=$left.Replace($prefix,'<CONSUMER_CHECKOUT>')}
                foreach($prefix in @($rightPrefix,$rightPrefix.Replace('\','/'))){$right=$right.Replace($prefix,'<CONSUMER_CHECKOUT>')}
                if($comparison.before -eq 'original' -and $comparison.after -eq 'relocated'){
                    $leftModule=Join-Path $root 'original-module/module'
                    $rightModule=Join-Path $root 'relocated-module/system/OpenGuidePlatform.Hugo.Guides'
                    foreach($prefix in @($leftModule,$leftModule.Replace('\','/'))){$left=$left.Replace($prefix,'<MODULE_CHECKOUT>')}
                    foreach($prefix in @($rightModule,$rightModule.Replace('\','/'))){$right=$right.Replace($prefix,'<MODULE_CHECKOUT>')}
                }
                if($left -ceq $right){$classification='checkout-path-only'}
            }
        }
        [ordered]@{path=$difference.path;classification=$classification}
    }
    [ordered]@{repository=$comparison.repository;ring=$comparison.ring;before=$comparison.before;after=$comparison.after;rawOutcome=$comparison.outcome;differences=@($differences)}
}
$result=[ordered]@{
    scope='Explanation only, not acceptance. Exact raw differences remain in comparison.json. Only the archived consumer and original/relocated module checkout prefixes are substituted for this classification; no timestamps, HTML, routes or other fields are ignored.'
    candidateCommit=$report.candidateCommit;records=@($records)
}
[IO.File]::WriteAllText($output,($result|ConvertTo-Json -Depth 20))
$records|ForEach-Object {
    $remaining=@($_.differences|Where-Object classification -NE 'checkout-path-only')
    [pscustomobject]@{repository=$_.repository;ring=$_.ring;before=$_.before;after=$_.after;checkoutPathOnly=@($_.differences|Where-Object classification -EQ 'checkout-path-only').Count;otherDifferences=$remaining.Count;otherPaths=($remaining.path -join ', ')}
}