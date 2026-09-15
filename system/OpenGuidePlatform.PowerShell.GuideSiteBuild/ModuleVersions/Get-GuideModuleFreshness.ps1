function Get-GuideModuleFreshness {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourcePath,[string]$ModulePath='github.com/nkdAgility/HugoGuides/module')
    if($ModulePath -notmatch '^[A-Za-z0-9][A-Za-z0-9./_-]+$' -or $ModulePath.Contains('..')){throw 'Invalid Go module path.'}
    try {
        $installed=Invoke-GuideGoModuleQuery $SourcePath $ModulePath
        $latest=Invoke-GuideGoModuleQuery $SourcePath "$ModulePath@latest"
        if(-not $installed.Version -or -not $latest.Version){throw 'Go returned incomplete version evidence.'}
        if($installed.PSObject.Properties['Replace']){
            return [pscustomobject]@{Code='MODULE_REPLACEMENT_ACTIVE';Severity='warning';Module=$ModulePath;Installed=$installed.Version;Latest=$latest.Version;Message='A module replacement is active; the declared pin is not proof of the source being built.'}
        }
        $current=$installed.Version -ceq $latest.Version
        [pscustomobject]@{Code=if($current){'MODULE_CURRENT'}else{'MODULE_VERSION_DIFFERS'};Severity=if($current){'info'}else{'warning'};Module=$ModulePath;Installed=$installed.Version;Latest=$latest.Version;Message=if($current){"Installed $($installed.Version) matches the latest version resolved by Go: $($latest.Version)."}else{"Installed $($installed.Version) differs from the latest version resolved by Go: $($latest.Version). Review the release and upgrade through a separate tested PR."}}
    } catch {
        [pscustomobject]@{Code='MODULE_FRESHNESS_UNAVAILABLE';Severity='warning';Module=$ModulePath;Installed=$null;Latest=$null;Message="Could not establish module freshness: $($_.Exception.Message)"}
    }
}
function Invoke-GuideGoModuleQuery {
    param([string]$SourcePath,[string]$Query)
    $command=Get-Command go -CommandType Application -ErrorAction Stop|Select-Object -First 1
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$command.Source;$start.WorkingDirectory=[IO.Path]::GetFullPath($SourcePath)
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    # Disable ambient workspace and mutable module flags; registry/cache access is read-only with respect to the consumer.
    $start.Environment['GOWORK']='off';$start.Environment['GOFLAGS']=''
    $start.ArgumentList.Add('list')
    if($env:OGP_BUILD_WORKSPACE){$start.Environment['GOWORK']=$env:OGP_BUILD_WORKSPACE}
    foreach($argument in @('-mod=readonly','-m','-json',$Query)){$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try {
        $null=$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)){$process.Kill($true);throw 'Go module query timed out.'}
        $raw=$stdout.GetAwaiter().GetResult();$diagnostics=$stderr.GetAwaiter().GetResult()
        if($process.ExitCode -ne 0){throw "Go module query failed ($($process.ExitCode)): $diagnostics"}
        ConvertFrom-Json $raw -ErrorAction Stop
    } finally {$process.Dispose()}
}