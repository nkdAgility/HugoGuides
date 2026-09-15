function Get-GuideSourcePages {
    param([string]$SourcePath,[string[]]$ConfigFiles,[string]$Target,$Configuration)
    # Hugo's list command uses SkipRender: it assembles source metadata with the site's
    # own configuration/templates, without rendering or replacing any content/layouts.
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=(Get-Command hugo -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.Environment['GOWORK']='off';$start.Environment['GOFLAGS']='-mod=readonly'
    foreach($argument in @('list','all','--noBuildLock','--source',$SourcePath,'--config',($ConfigFiles -join ','),'--environment',$Target)){$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try{
        $null=$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(60000)){$process.Kill($true);throw 'Hugo source listing timed out.'}
        $csv=$stdout.GetAwaiter().GetResult();$diagnostics=$stderr.GetAwaiter().GetResult()
        if($process.ExitCode -ne 0){throw "Hugo source listing failed: $diagnostics"}
        $header=[regex]::Match($csv,'(?m)^path,slug,title,')
        if(-not $header.Success) {throw 'Hugo did not return its source inventory CSV.'}
        $csv=$csv.Substring($header.Index)
        $now=[DateTimeOffset]::UtcNow
        foreach($page in @($csv|ConvertFrom-Csv)){
            if($page.draft -eq 'true' -and -not $Configuration.builddrafts){continue}
            if([DateTimeOffset]::Parse($page.publishDate) -gt $now -and -not $Configuration.buildfuture){continue}
            $expiry=[DateTimeOffset]::Parse($page.expiryDate)
            if($expiry.Year -gt 1 -and $expiry -lt $now -and -not $Configuration.buildexpired){continue}
            if(-not $page.permalink){continue}
            $page
        }
    }finally{$process.Dispose()}
}
