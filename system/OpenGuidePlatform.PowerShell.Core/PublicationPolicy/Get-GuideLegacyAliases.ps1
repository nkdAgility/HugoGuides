function Get-GuideLegacyAliasTargets {
    param([Parameter(Mandatory)][Collections.IDictionary]$Policy,[string[]]$EnabledLanguages=@())
    $counts=@{}
    if($Policy.wrapper.Contains('legacyAliases')){
        foreach($entry in $Policy.wrapper.legacyAliases){
            if($entry.language -notin $EnabledLanguages){continue}
            foreach($target in $entry.targets){
                if($target -cnotmatch '^(?:[A-Za-z0-9-]+/){0,2}(?:download|downloads|translationsdirectory)/index\.html$'){throw "Not a legacy alias target: $target"}
                if(-not $counts.ContainsKey($target)){$counts[$target]=0}
                $counts[$target]++
            }
        }
    }
    return $counts
}
function Test-GuideLegacyAliases {
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][Collections.IDictionary]$Policy)
    $approved=@{};$seen=@{};$findings=[Collections.Generic.List[object]]::new()
    if($Policy.wrapper.Contains('legacyAliases')){foreach($entry in $Policy.wrapper.legacyAliases){
        if($approved.ContainsKey($entry.source)){throw "Duplicate legacy alias source: $($entry.source)"}
        if($entry.aliases.Count -ne $entry.targets.Count){throw "Legacy aliases and target counts disagree: $($entry.source)"}
        $approved[$entry.source]=$entry
    }}
    $source=Resolve-GuideWorkspacePath $WorkspaceRoot $Policy.wrapper.sourcePath
    foreach($file in Get-ChildItem -LiteralPath $source -Filter '*.md' -Recurse -File){
        $relative=[IO.Path]::GetRelativePath([IO.Path]::GetFullPath($WorkspaceRoot),$file.FullName).Replace('\','/')
        $path=Resolve-GuideWorkspacePath $WorkspaceRoot $relative
        $raw=[IO.File]::ReadAllText($path)
        if($raw -notmatch '\A---\r?\n' -or $raw -notmatch '(?m)^[ \t]*aliases[ \t]*:'){continue}
        $document=Read-GuideDocument $path
        $aliases=@(if($document.Metadata.Contains('aliases')){$document.Metadata.aliases|Where-Object {$_ -cmatch '^/(?:[A-Za-z0-9-]+/)?(?:download|downloads|translationsdirectory)/?$'}})
        if(-not $aliases.Count){continue}
        $seen[$relative]=$true
        if(-not $approved.ContainsKey($relative) -or (($aliases|Sort-Object) -join "`n") -cne (($approved[$relative].aliases|Sort-Object) -join "`n")){
            $findings.Add([pscustomobject]@{Code='LEGACY_ALIAS_DECLARATION_CHANGED';Path=$relative;Message='Preserve the frozen existing legacy aliases. Do not extend them to new languages or sources.'})
        }
    }
    foreach($path in $approved.Keys){if(-not $seen.ContainsKey($path)){$findings.Add([pscustomobject]@{Code='LEGACY_ALIAS_DECLARATION_MISSING';Path=$path;Message='Restore the frozen legacy declaration or review its deliberate retirement.'})}}
    [pscustomobject]@{Outcome=if($findings.Count){'fail'}else{'pass'};Findings=$findings.ToArray()}
}
