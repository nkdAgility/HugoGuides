#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$CandidateCommit,
    [Parameter(Mandatory)][string]$TrustedPolicyPath,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedPolicySha256,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')][string]$Repository
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$workspace=[IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$policyPath=[IO.Path]::GetFullPath($TrustedPolicyPath)
$comparison=if($IsWindows){[StringComparison]::OrdinalIgnoreCase}else{[StringComparison]::Ordinal}
foreach($trusted in @($policyPath,$PSCommandPath)){
    if($trusted.Equals($workspace,$comparison) -or $trusted.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,$comparison)){throw 'Evaluator and trusted policy must be outside the candidate workspace.'}
    $cursor=$trusted
    while($cursor){
        if((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked trusted paths are not accepted.'}
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
}
$policyBytes=[IO.File]::ReadAllBytes($policyPath)
$digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($policyBytes)).ToLowerInvariant()
if($digest -cne $ExpectedPolicySha256){throw 'Trusted policy digest differs from the independently supplied identity.'}
$policy=[Text.Encoding]::UTF8.GetString($policyBytes)|ConvertFrom-Json -AsHashtable
$fields=@('schemaVersion','repository','baselineCommit','protectedPaths','protectedFileNames')
if($policy.Count -ne $fields.Count -or @($fields|Where-Object {-not $policy.ContainsKey($_)}).Count -or $policy.schemaVersion -ne 1 -or $policy.repository -cne $Repository -or $policy.baselineCommit -cnotmatch '^[a-f0-9]{40}$'){throw 'Invalid trusted governance policy or repository identity.'}
if($policy.protectedPaths -isnot [array] -or $policy.protectedFileNames -isnot [array]){throw 'Trusted protection selectors must be arrays.'}
foreach($entry in $policy.protectedPaths){
    if($entry -isnot [string] -or $entry -match '(^/|[\\:*?\x00-\x1f]|(^|/)\.\.?(/|$)|//)' -or [string]::IsNullOrWhiteSpace($entry)){throw 'Unsafe protected path selector.'}
}
foreach($entry in $policy.protectedFileNames){if($entry -isnot [string] -or $entry -notmatch '^[A-Za-z0-9_.*-]+$'){throw 'Unsafe protected filename selector.'}}
$git=(Get-Command git -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source
function Read-CommitTree([string]$Commit){
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$git;$start.WorkingDirectory=$workspace
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    foreach($argument in @('ls-tree','-r','-z','--full-tree',$Commit)){$start.ArgumentList.Add($argument)}
    # No checkout, hooks, filters, textconv or candidate executables are involved.
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try{
        $null=$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)){$process.Kill($true);throw 'Git tree read timed out.'}
        $raw=$stdout.GetAwaiter().GetResult();$diagnostics=$stderr.GetAwaiter().GetResult()
        if($process.ExitCode -ne 0){throw "Cannot read governed commit: $diagnostics"}
        $tree=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach($record in $raw.Split([char]0,[StringSplitOptions]::RemoveEmptyEntries)){
            if($record -notmatch '^(?<identity>[0-9]{6} (?:blob|commit) [a-f0-9]{40})\t(?<path>[\s\S]+)$'){throw 'Invalid Git tree record.'}
            if(-not $tree.TryAdd($Matches.path,($Matches.identity+"`t"+$Matches.path))){throw 'Case-colliding candidate paths are not portable.'}
        }
        return ,$tree
    }finally{$process.Dispose()}
}
$baseline=Read-CommitTree $policy.baselineCommit
$candidate=Read-CommitTree $CandidateCommit
$paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($path in @($baseline.Keys)+@($candidate.Keys)){$null=$paths.Add($path)}
$protectedPaths=@('.github','.agents','.codex','.claude','build.ps1','bootstrap.ps1','guide-site.policy.json','platform-lock.json','open-guide-platform.installation.json')+@($policy.protectedPaths)
$protectedNames=@('.gitattributes','.gitmodules','.gitignore','AGENTS.md','CLAUDE.md','agents.md','copilot-instructions.md','go.mod','go.sum','go.work','go.work.sum','hugo*.yaml','hugo*.yml','hugo*.toml','hugo*.json')+@($policy.protectedFileNames)
$findings=[Collections.Generic.List[object]]::new()
foreach($path in $paths|Sort-Object){
    $protected=@($protectedPaths|Where-Object {$prefix=$_.TrimEnd('/');$path.Equals($prefix,[StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith($prefix+'/',[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0
    if($path -match '(?:^|/)\.(?:github|agents|codex|claude)(?:/|$)'){$protected=$true}
    $name=($path -split '/')[-1]
    if(-not $protected){$protected=@($protectedNames|Where-Object {$name -like $_}).Count -gt 0}
    if(-not $protected){continue}
    $before=if($baseline.ContainsKey($path)){$baseline[$path]}else{$null}
    $after=if($candidate.ContainsKey($path)){$candidate[$path]}else{$null}
    if($before -cne $after){$findings.Add([ordered]@{code='PROTECTED_CHANGE_REQUIRES_REVIEW';path=$path;before=$before;after=$after;remediation='A maintainer must review this exact change and update the externally controlled baseline; candidate settings cannot approve it.'})}
}
[ordered]@{schemaVersion=1;repository=$Repository;sourceCommit=$CandidateCommit;baselineCommit=$policy.baselineCommit;policySha256=$digest;outcome=if($findings.Count){'blocked'}else{'pass'};findings=$findings.ToArray()}|ConvertTo-Json -Depth 10
if($findings.Count){exit 1}