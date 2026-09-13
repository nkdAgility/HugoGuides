function Get-GuideDownloadRequirements {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][Collections.IDictionary]$Policy,[Parameter(Mandatory)][string]$Target,[Parameter(Mandatory)][AllowEmptyCollection()][string[]]$EnabledLanguages)
    $required=[Collections.Generic.List[object]]::new();$forbidden=[Collections.Generic.List[object]]::new();$findings=[Collections.Generic.List[object]]::new()
    foreach($guide in $Policy.guides){foreach($edition in $guide.editions){foreach($translation in $edition.translations){
        $excluded=$translation.intent -in @('excluded','scaffold') -or ($translation.intent -ne 'pdf-only' -and $translation.language -cnotin $EnabledLanguages)
        foreach($rule in $Policy.publication.permanentExclusions){
            if($rule.environment -cne $Target){continue}
            if(($rule.subject -eq 'language' -and $rule.id -ceq $translation.language) -or ($rule.subject -eq 'guide' -and $rule.id -ceq $guide.id) -or ($rule.subject -eq 'edition' -and $rule.id -ceq "$($guide.id)/$($edition.id)")){$excluded=$true}
        }
        foreach($download in $translation.downloads){
            $source="$($guide.contentRoot)/$($edition.path)/$($download.path)"
            $file=Resolve-GuideWorkspacePath $WorkspaceRoot $source
            $paths=@(if($download.Contains('publishedPaths')){$download.publishedPaths})
            foreach($path in $paths){if([string]::IsNullOrWhiteSpace($path) -or $path.StartsWith('/') -or $path -match '[\\:?#%]' -or @($path.Split('/')|Where-Object {$_ -in @('..','.','')}).Count){throw "Unsafe published download path: $path"}}
            $hash=if([IO.File]::Exists($file)){(Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant()}else{$null}
            $record=[pscustomobject]@{Subject="$($guide.id)/$($edition.id)/$($translation.language)";SourcePath=$source;PublishedPaths=$paths;Sha256=$hash;Handling=$download.handling}
            if($excluded){$forbidden.Add($record)}else{
                if(-not $paths.Count){$findings.Add([pscustomobject]@{Code='DOWNLOAD_PUBLICATION_PATH_UNDECLARED';Path=$source;Message='Declare the existing publishedPaths for this download in the reviewed policy; source paths are not public URLs.'})}
                if(-not $hash){$findings.Add([pscustomobject]@{Code='DOWNLOAD_SOURCE_MISSING';Path=$source;Message='Restore the supplied/protected PDF or generate the declared generated resource before Prepare.'})}
                $required.Add($record)
            }
        }
    }}}
    [pscustomobject]@{Required=$required.ToArray();Forbidden=$forbidden.ToArray();RequiredPaths=@($required|ForEach-Object PublishedPaths|Select-Object -Unique);ForbiddenPaths=@($forbidden|ForEach-Object PublishedPaths|Select-Object -Unique);Findings=$findings.ToArray()}
}
function Test-GuideDownloadPublication {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Requirements,[Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ArtifactFiles)
    $findings=[Collections.Generic.List[object]]::new()
    foreach($finding in $Requirements.Findings){$findings.Add($finding)}
    $allowed=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($record in $Requirements.Required){foreach($path in $record.PublishedPaths){
        $matches=@($ArtifactFiles|Where-Object Path -CEQ $path)
        if($matches.Count -ne 1){$findings.Add([pscustomobject]@{Code='REQUIRED_DOWNLOAD_MISSING';Path=$path;Message="Restore the published download for $($record.Subject)."})}
        elseif(-not $record.Sha256 -or $matches[0].Sha256 -cne $record.Sha256){$findings.Add([pscustomobject]@{Code='DOWNLOAD_BYTES_CHANGED';Path=$path;Message="Published bytes differ from the declared source $($record.SourcePath)."})}
        else{$null=$allowed.Add($path)}
    }}
    foreach($record in $Requirements.Forbidden){foreach($file in $ArtifactFiles){
        $matches=$file.Path -cin $record.PublishedPaths -or ($record.Sha256 -and $file.Sha256 -ceq $record.Sha256) -or [IO.Path]::GetFileName($file.Path) -ceq [IO.Path]::GetFileName($record.SourcePath)
        # A shared supplied/fallback PDF is allowed only at an explicitly required path with matching bytes.
        if($matches -and -not $allowed.Contains($file.Path)){$findings.Add([pscustomobject]@{Code='FORBIDDEN_DOWNLOAD_PRESENT';Path=$file.Path;Message="Remove the excluded download for $($record.Subject), including copies outside its language directory."})}
    }}
    [pscustomobject]@{Outcome=if($findings.Count){'fail'}else{'pass'};Findings=$findings.ToArray()}
}