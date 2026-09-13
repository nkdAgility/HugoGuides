Set-StrictMode -Version Latest
function Export-SourceArchive($repository,$commit,$destination,$subtree){
    $zip=$destination+'.zip'
    $arguments=@('-C',$repository,'archive','--format=zip',"--output=$zip",$commit)
    if($subtree){$arguments+= $subtree}
    & git @arguments
    if($LASTEXITCODE -ne 0){throw "Cannot archive $repository at $commit."}
    Expand-Archive -LiteralPath $zip -DestinationPath $destination
}
function Invoke-CapturedTool($tool,$arguments,$workingDirectory,$log){
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=(Get-Command $tool -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source
    $start.WorkingDirectory=$workingDirectory;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    # Do not inherit an unrelated Go workspace or Hugo source/cache override.
    foreach($key in @('HUGO_ENV','HUGO_ENVIRONMENT','HUGO_RESOURCEDIR','GOFLAGS')){$start.Environment.Remove($key)|Out-Null}
    $start.Environment['GOWORK']='off'
    foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try {
        $null=$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        $timedOut=-not $process.WaitForExit(120000)
        if($timedOut){$process.Kill($true);$process.WaitForExit()}
        $text=$stdout.GetAwaiter().GetResult()+"`n"+$stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText($log,$text)
        [pscustomobject]@{exitCode=$process.ExitCode;timedOut=$timedOut;errors=([regex]::Matches($text,'(?m)^ERROR')).Count;warnings=([regex]::Matches($text,'(?m)^WARN')).Count}
    } finally {$process.Dispose()}
}
function Get-ArtifactInventory($directory){
    if(-not (Test-Path -LiteralPath $directory)){return}
    Get-ChildItem -LiteralPath $directory -Recurse -File|Sort-Object FullName|ForEach-Object {
        [ordered]@{path=[IO.Path]::GetRelativePath($directory,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
}
Export-ModuleMember -Function Export-SourceArchive,Invoke-CapturedTool,Get-ArtifactInventory
