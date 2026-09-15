function Publish-PlatformWorkflowAliases {
    param([string]$WorkspaceRoot,[string]$Repository,[string]$Version,[string]$Commit)
    $versionNumber=[System.Management.Automation.SemanticVersion]$Version
    $suffix=if($versionNumber.PreReleaseLabel){'-preview'}else{''}
    $aliases=@("v$($versionNumber.Major)$suffix","v$($versionNumber.Major).$($versionNumber.Minor)$suffix")
    $remote="https://github.com/$Repository.git"
    $raw=@(& git ls-remote --refs $remote 'refs/tags/v*')
    if($LASTEXITCODE -ne 0){throw 'Cannot inspect workflow aliases. The immutable release is published; rerun Release to finish alias publication.'}
    $refs=@{}
    foreach($line in $raw){$parts=$line -split '\s+';if($parts.Count -eq 2){$refs[$parts[1]]=$parts[0]}}
    foreach($alias in $aliases){
        $ref="refs/tags/$alias";$expected=if($refs.ContainsKey($ref)){$refs[$ref]}else{''}
        if($expected -ceq $Commit){continue}
        if($expected){
            $priorVersions=@(foreach($name in $refs.Keys){
                if($refs[$name] -cne $expected -or $name -cnotmatch '^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$'){continue}
                $prior=[System.Management.Automation.SemanticVersion]$name.Substring(11)
                if([bool]$prior.PreReleaseLabel -eq [bool]$versionNumber.PreReleaseLabel){$prior}
            })
            if(-not $priorVersions.Count){throw "Workflow alias $alias does not identify an immutable release tag. Reconcile it before publishing aliases."}
            if(@($priorVersions|Where-Object {$_ -gt $versionNumber}).Count){Write-Host "Keeping newer workflow alias $alias.";continue}
        }
        # Lease rejects concurrent publication rather than overwriting a newer alias.
        & git -C $WorkspaceRoot -c credential.helper= -c 'credential.helper=!gh auth git-credential' push "--force-with-lease=${ref}:$expected" $remote "${Commit}:$ref"
        if($LASTEXITCODE -ne 0){throw "Workflow alias $alias changed concurrently or could not be published. The release is intact; rerun Release."}
        Write-Host "Published workflow alias $alias -> v$Version."
    }
}
