function New-GuideEdition {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][System.Collections.IDictionary]$Policy,[Parameter(Mandatory)][string]$GuideId,[Parameter(Mandatory)][string]$SourceEditionId,[Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$NewEditionId,[Parameter(Mandatory)][string]$TargetPath)
    $selection=Get-GuideSelection $Policy $GuideId $SourceEditionId
    if ($NewEditionId -in @($selection.Guide.editions.id)) { throw 'Edition ID already exists.' }
    $relative="$($selection.Guide.contentRoot)/$TargetPath"
    $target=Resolve-GuideWorkspacePath $WorkspaceRoot $relative
    $source=Resolve-GuideWorkspacePath $WorkspaceRoot $selection.RelativePath
    Assert-GuideWriteAllowed $Policy $relative
    if (Test-Path -LiteralPath $target) { throw 'Edition target already exists; replacement is not supported.' }
    if (-not [IO.Directory]::Exists($source)) { throw 'Source edition directory is missing.' }
    # Materialize source before writing; never recursively copy a target nested in its source.
    if ($target.StartsWith($source+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Edition target must not be inside its source.' }
    $entries=@(Get-ChildItem -LiteralPath $source -Recurse -Force)
    if (@($entries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Edition contains linked resources; snapshot refused.' }
    $files=@($entries | Where-Object { -not $_.PSIsContainer -and $_.Name -notin @('.hugo_build.lock','.DS_Store') })
    $outputs=@(foreach ($file in $files) {
        $relativeFile=[IO.Path]::GetRelativePath($source,$file.FullName).Replace('\','/')
        $destination=Resolve-GuideWorkspacePath $WorkspaceRoot "$relative/$relativeFile"
        Assert-GuideWriteAllowed $Policy "$relative/$relativeFile"
        $content=$null
        if ($file.Name -match '^index(?:\.[^.]+)?\.md$') {
            $document=Read-GuideDocument $file.FullName
            # New snapshots are drafts and never inherit live aliases. Source bodies are byte-preserved as text.
            $metadata=$document.Metadata
            $metadata.Remove('aliases') | Out-Null
            $metadata.Remove('lang') | Out-Null
            $metadata['version']=$NewEditionId;$metadata['draft']=$true
            $yaml=ConvertTo-Yaml $metadata
            $content="---`n$($yaml.TrimEnd())`n---`n$($document.Body)"
        }
        [pscustomobject]@{Source=$file.FullName;Target=$destination;Content=$content}
    })
    if ($PSCmdlet.ShouldProcess($target,'Create a new draft edition without changing source or live aliases')) {
        # Exclusive directory creation is enforced by a sibling lock file; no Force/delete path exists.
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        $lockPath=$target+'.edition-lock'
        $lock=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $staging=$target+'.staging-'+[guid]::NewGuid().ToString('N')
        try {
            if (Test-Path -LiteralPath $target) { throw 'Edition target appeared during preparation.' }
            [IO.Directory]::CreateDirectory($staging) | Out-Null
            foreach ($file in $outputs) {
                $stagedFile=Join-Path $staging ([IO.Path]::GetRelativePath($target,$file.Target))
                if ($null -ne $file.Content) { New-GuideFile $stagedFile $file.Content }
                else { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($stagedFile)) | Out-Null;[IO.File]::Copy($file.Source,$stagedFile,$false) }
            }
            # Same-parent rename publishes only a complete snapshot and refuses an existing target.
            $checked=Resolve-GuideWorkspacePath $WorkspaceRoot $relative
            Assert-GuideWriteAllowed $Policy $relative
            [IO.Directory]::Move($staging,$checked)
        } finally {
            try {
                # Cleanup is restricted to the unique staging directory created by this operation.
                $rootPath=[IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
                $stagePath=[IO.Path]::GetFullPath($staging)
                if (-not $stagePath.StartsWith($rootPath,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetDirectoryName($stagePath) -ne [IO.Path]::GetDirectoryName($target)) { throw 'Unsafe staging cleanup path.' }
                if ([IO.Directory]::Exists($stagePath)) { [IO.Directory]::Delete($stagePath,$true) }
            } finally { $lock.Dispose();[IO.File]::Delete($lockPath) }
        }
        [pscustomobject]@{Status='created-draft';Guide=$GuideId;Edition=$NewEditionId;Path=$relative;Files=$outputs.Count;SourceChanged=$false;RequiresPublicationReview=$true}
    }
}
