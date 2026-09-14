function New-PlatformBuildFailure {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Why,[Parameter(Mandatory)][string]$HowToFix,[string]$Subject='Platform build')
    $failure=[InvalidOperationException]::new($Why)
    $failure.Data['Why']=$Why
    $failure.Data['HowToFix']=$HowToFix
    $failure.Data['Subject']=$Subject
    return $failure
}
function Write-PlatformTestSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Result,[Parameter(Mandatory)][string]$OutputPath,
        [string]$SummaryPath=$env:GITHUB_STEP_SUMMARY,[ValidateSet('Local','GitHub')][string]$Reporter=$(if($env:GITHUB_ACTIONS -eq 'true'){'GitHub'}else{'Local'}))
    function Escape-Markdown($value){[Net.WebUtility]::HtmlEncode([string]$value).Replace('|','&#124;').Replace('`','&#96;').Replace('@','&#64;')}
    function Escape-Annotation($value){([string]$value).Replace('%','%25').Replace("`r",'%0D').Replace("`n",'%0A')}
    $lines=[Collections.Generic.List[string]]::new()
    $lines.Add("## Platform tests: $($Result.Result.ToLowerInvariant())")
    $lines.Add('')
    $lines.Add("Passed: $($Result.PassedCount); failed: $($Result.FailedCount); skipped: $($Result.SkippedCount).")
    $findings=[Collections.Generic.List[object]]::new()
    foreach($collection in @('Failed','FailedBlocks','FailedContainers')){
        $property=$Result.PSObject.Properties[$collection]
        if(-not $property){continue}
        foreach($item in $property.Value){
            foreach($errorRecord in $item.ErrorRecord){
                $exception=$errorRecord.Exception
                $name=if($item.PSObject.Properties['ExpandedPath']){$item.ExpandedPath}elseif($item.PSObject.Properties['Name']){$item.Name}else{'Test discovery/setup'}
                $why=$exception.Data['Why'];$fix=$exception.Data['HowToFix']
                if(-not $why){$why="The check '$name' failed without a recorded plain-language diagnosis. The technical error is included below."}
                if(-not $fix){$fix='The platform maintainer needs to diagnose this check; an automatic repair is not known. Run ./build.ps1 -Stage Build, use the test and source location below, and add an explicit Why/HowToFix explanation with the correction. Do not bypass the check.'}
                $location=if($errorRecord.InvocationInfo.ScriptName){"$($errorRecord.InvocationInfo.ScriptName):$($errorRecord.InvocationInfo.ScriptLineNumber)"}else{'See technical detail'}
                $finding=[ordered]@{test=$name;why=$why;howToFix=$fix;location=$location;technicalDetail=$exception.Message}
                $findings.Add($finding)
                $lines.Add('');$lines.Add("### $(Escape-Markdown $name)");$lines.Add('')
                $lines.Add("**Why:** $(Escape-Markdown $why)");$lines.Add('')
                $lines.Add("**How to fix:** $(Escape-Markdown $fix)");$lines.Add('')
                $lines.Add("Location: $(Escape-Markdown $location)");$lines.Add('')
                $lines.Add("Technical detail: $(Escape-Markdown $exception.Message)")
                if($Reporter -eq 'GitHub'){
                    Write-Host "::error title=Platform build failed::$(Escape-Annotation "Why: $why How to fix: $fix Location: $location")"
                }
            }
        }
    }
    if($Result.TotalCount -eq 0 -and -not $findings.Count){
        $lines.Add('');$lines.Add('**Why:** No tests ran, so this build has no test evidence.')
        $lines.Add('');$lines.Add('**How to fix:** Restore the tests/Core files and verify that WorkspaceRoot points to the platform checkout, then rerun ./build.ps1 -Stage Build.')
    }
    [IO.Directory]::CreateDirectory($OutputPath)|Out-Null
    $markdown=$lines -join "`n"
    [IO.File]::WriteAllText((Join-Path $OutputPath 'summary.md'),$markdown)
    [IO.File]::WriteAllText((Join-Path $OutputPath 'findings.json'),(ConvertTo-Json -InputObject @($findings) -Depth 10))
    if($SummaryPath){[IO.File]::AppendAllText($SummaryPath,$markdown+"`n")}
    Write-Host ([Net.WebUtility]::HtmlDecode($markdown))
    Write-Host "Test report: $(Join-Path $OutputPath 'summary.md')"
}
