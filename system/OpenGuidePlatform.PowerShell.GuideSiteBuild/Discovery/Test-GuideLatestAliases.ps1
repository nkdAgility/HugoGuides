function Test-GuideLatestAliases {
    [CmdletBinding()]
    param([string]$WorkspaceRoot,$Policy,[string[]]$Languages,[datetimeoffset]$Now=[datetimeoffset]::UtcNow)
    $findings=[Collections.Generic.List[object]]::new()
    $content=Join-Path $WorkspaceRoot "$($Policy.wrapper.sourcePath)/content"
    $documents=@(Get-ChildItem $content -Filter '*.md' -Recurse -File|ForEach-Object {
        $document=Read-GuideDocument $_.FullName
        [pscustomobject]@{Path=$_.FullName;Metadata=$document.Metadata}
    })
    foreach($guide in $Policy.guides){
        $guideRoot=Join-Path $WorkspaceRoot $guide.contentRoot
        $guideRoute=[IO.Path]::GetRelativePath($content,$guideRoot).Replace('\','/').ToLowerInvariant()
        $alias="/$guideRoute/latest"
        foreach($language in $Languages){
            $candidates=@(foreach($edition in $guide.editions){
                $suffix=if($language -eq $edition.sourceLanguage){''}else{".$language"}
                $path=Join-Path $guideRoot "$($edition.path)/index$suffix.md"
                $entry=$documents|Where-Object Path -eq $path|Select-Object -First 1
                if(-not $entry){continue}
                $base=$documents|Where-Object Path -eq (Join-Path $guideRoot "$($edition.path)/index.md")|Select-Object -First 1
                $metadata=$entry.Metadata
                $dateValue=if($metadata.Contains('date')){$metadata.date}else{$base.Metadata['date']}
                $date=[datetimeoffset]::MinValue
                if($dateValue){$date=[datetimeoffset]::Parse([string]$dateValue,[cultureinfo]::InvariantCulture)}
                $publish=$date
                if($metadata.Contains('publishDate')){$publish=[datetimeoffset]::Parse([string]$metadata.publishDate,[cultureinfo]::InvariantCulture)}
                $expired=$metadata.Contains('expiryDate') -and ([datetimeoffset]::Parse([string]$metadata.expiryDate,[cultureinfo]::InvariantCulture) -le $Now)
                $draft=$metadata['draft'] -eq $true -or $base.Metadata['draft'] -eq $true
                [pscustomobject]@{Path=$path;Date=$date;Published=(-not $draft -and -not $expired -and $publish -le $Now);Suffix=$suffix}
            })
            if(-not $candidates.Count){continue}
            $suffix=$candidates[0].Suffix
            $owners=@($documents|Where-Object {
                $documentLanguageMatches=if($suffix){$_.Path.EndsWith("$suffix.md",[StringComparison]::OrdinalIgnoreCase)}else{[IO.Path]::GetFileName($_.Path) -notmatch '\.[a-zA-Z]{2,8}(?:-[a-zA-Z0-9]+)*\.md$'}
                $documentLanguageMatches -and @($_.Metadata['aliases']|Where-Object {([string]$_).TrimEnd('/') -ceq $alias}).Count
            })
            $published=@($candidates|Where-Object Published|Sort-Object Date -Descending)
            $latest=if($published.Count){$published[0]}else{$null}
            if($latest -and $owners.Count -eq 1 -and $owners[0].Path -eq $latest.Path){continue}
            if(-not $latest -and -not $owners.Count){continue}
            $expected=if($latest){[IO.Path]::GetRelativePath($WorkspaceRoot,$latest.Path).Replace('\','/')}else{'no published edition'}
            $actual=@($owners|ForEach-Object {[IO.Path]::GetRelativePath($WorkspaceRoot,$_.Path).Replace('\','/')})
            $fix=if($latest){"Add '$alias' to the front matter aliases in $expected and remove it from every other $language page. Draft and future editions must not own latest."}else{"Remove '$alias' from $($actual -join ', '); this language has no published, non-draft edition."}
            $findings.Add([ordered]@{code='GUIDE_LATEST_ALIAS_INVALID';severity='blocker';scope='guide';subject="$($guide.id)/$language";message="The /$language$alias alias must belong only to the latest published, non-draft edition. Expected: $expected. Current owners: $(if($actual.Count){$actual -join ', '}else{'none'}).";remediation=$fix;evidence=$actual})
        }
    }
    return @($findings)
}
