function Test-GuideWrapperValueEqual {
    param($Left,$Right)
    if($null -eq $Left -or $null -eq $Right){return $null -eq $Left -and $null -eq $Right}
    if($Left -is [Collections.IDictionary]){
        if($Right -isnot [Collections.IDictionary] -or $Left.Count -ne $Right.Count){return $false}
        foreach($key in $Left.Keys){if(-not $Right.Contains($key) -or -not (Test-GuideWrapperValueEqual $Left[$key] $Right[$key])){return $false}}
        return $true
    }
    if($Left -is [Collections.IList]){
        if($Right -isnot [Collections.IList] -or $Left.Count -ne $Right.Count){return $false}
        for($index=0;$index -lt $Left.Count;$index++){if(-not (Test-GuideWrapperValueEqual $Left[$index] $Right[$index])){return $false}}
        return $true
    }
    return $Left.GetType() -eq $Right.GetType() -and $Left -ceq $Right
}
function Set-GuideWrapperTranslation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$WorkspaceRoot,
        [Parameter(Mandatory)][Collections.IDictionary]$Policy,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$')][string]$Language,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$CandidateContent,
        [ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSha256
    )
    $target=Resolve-GuideWorkspacePath $WorkspaceRoot $RelativePath
    Assert-GuideWriteAllowed $Policy $RelativePath
    $wrapper=$Policy.wrapper.sourcePath.TrimEnd('/')
    foreach($guide in $Policy.guides){
        if($RelativePath.Equals($guide.contentRoot,[StringComparison]::OrdinalIgnoreCase) -or $RelativePath.StartsWith($guide.contentRoot.TrimEnd('/')+'/',[StringComparison]::OrdinalIgnoreCase)){throw 'Wrapper operations must not modify guide content; select the guide operation.'}
    }
    $configuration=$RelativePath -cin @("$wrapper/hugo.yaml","$wrapper/hugo.production.yaml")
    $catalogue=$RelativePath -cin @("$wrapper/i18n/$Language.yaml","$wrapper/i18n/$Language.yml")
    $markdown=$RelativePath.StartsWith("$wrapper/content/",[StringComparison]::Ordinal) -and $RelativePath.EndsWith(".$Language.md",[StringComparison]::Ordinal)
    if(-not ($configuration -or $catalogue -or $markdown)){throw 'Select a language-specific wrapper Markdown/catalogue file or its Hugo language configuration.'}
    $exists=[IO.File]::Exists($target)
    if($exists -and -not $ExpectedSha256){throw 'Wrapper file exists; preserve it or supply its reviewed ExpectedSha256.'}
    if($ExpectedSha256 -and (-not $exists -or (Get-FileHash -LiteralPath $target).Hash -ine $ExpectedSha256)){throw 'Wrapper file changed since review or is missing.'}
    Import-Module powershell-yaml -RequiredVersion 0.4.12 -ErrorAction Stop
    if($configuration){
        if(-not $exists){throw 'Existing Hugo configuration is required; do not invent wrapper configuration.'}
        $before=ConvertFrom-Yaml ([IO.File]::ReadAllText($target))
        $after=ConvertFrom-Yaml $CandidateContent
        foreach($value in @($before,$after)){if($value -isnot [Collections.IDictionary]){throw 'Expected a Hugo configuration mapping.'}}
        if(-not $after.Contains('languages') -or $after.languages -isnot [Collections.IDictionary] -or -not $after.languages.Contains($Language) -or $after.languages[$Language] -isnot [Collections.IDictionary]){throw 'Candidate must declare the selected language.'}
        if($RelativePath.EndsWith('/hugo.production.yaml') -and (-not $after.languages[$Language].Contains('disabled') -or $after.languages[$Language].disabled -ne $true)){throw 'Wrapper translation operations keep the selected production language disabled.'}
        $newLanguage=-not ($before.Contains('languages') -and $before.languages.Contains($Language))
        # Only the selected language may change; preserve other languages and all wrapper settings.
        $after.languages.Remove($Language)|Out-Null
        if($before.Contains('languages')){
            if($before.languages -isnot [Collections.IDictionary]){throw 'Expected existing language mappings.'}
            $before.languages.Remove($Language)|Out-Null
        }else{$before.languages=@{}}
        if(-not (Test-GuideWrapperValueEqual $before $after)){throw 'Candidate changes unselected languages or unrelated wrapper configuration.'}
    }elseif($catalogue){
        $other=if($RelativePath.EndsWith('.yaml')){$RelativePath.Substring(0,$RelativePath.Length-5)+'.yml'}else{$RelativePath.Substring(0,$RelativePath.Length-4)+'.yaml'}
        if(Test-Path -LiteralPath (Resolve-GuideWorkspacePath $WorkspaceRoot $other)){throw 'Preserve one authoritative catalogue extension; both YAML extensions are ambiguous.'}
        $catalog=ConvertFrom-Yaml $CandidateContent
        if($catalog -isnot [Collections.IDictionary] -and $catalog -isnot [Collections.IList]){throw 'Expected a YAML translation catalogue.'}
        if($catalog -is [Collections.IList]){
            $ids=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach($entry in $catalog){if($entry -isnot [Collections.IDictionary] -or -not $entry.Contains('id') -or [string]::IsNullOrWhiteSpace($entry.id) -or -not $ids.Add($entry.id)){throw 'Catalogue entries require unique nonempty ids.'}}
        }
    }else{
        $match=[regex]::Match($CandidateContent,'\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)(?<body>.*)\z',[Text.RegularExpressions.RegexOptions]::Singleline)
        if(-not $match.Success){throw 'Expected wrapper Markdown with YAML front matter.'}
        $metadata=ConvertFrom-Yaml $match.Groups['yaml'].Value
        if($metadata -isnot [Collections.IDictionary] -or $metadata.Contains('lang')){throw 'Wrapper front matter must be a mapping without lang.'}
        $prior=if($exists){(Read-GuideDocument $target).Metadata}else{@{}}
        $oldAliases=if($prior.Contains('aliases')){@($prior.aliases)}else{@()}
        if($metadata.Contains('aliases')){
            foreach($alias in $metadata.aliases){if($alias -match '^/(?:[A-Za-z0-9-]+/)?(?:download|downloads|translationsdirectory)/?$' -and $alias -cnotin $oldAliases){throw 'Do not extend legacy shared download aliases into wrapper translations.'}}
        }
    }
    if(-not $exists -or ($configuration -and $RelativePath.EndsWith('/hugo.yaml') -and $newLanguage)){
        $production=ConvertFrom-Yaml ([IO.File]::ReadAllText((Resolve-GuideWorkspacePath $WorkspaceRoot "$wrapper/hugo.production.yaml")))
        if(-not $production.Contains('languages') -or -not $production.languages.Contains($Language) -or $production.languages[$Language].disabled -ne $true){throw 'Declare the selected language disabled in production before creating wrapper files or changing its main configuration.'}
    }
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($CandidateContent)
    $digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    if($exists -and $digest -ieq $ExpectedSha256){return [pscustomobject]@{Status='unchanged';Path=$RelativePath;Sha256=$digest}}
    if($PSCmdlet.ShouldProcess($target,'Apply the reviewed wrapper translation candidate')){
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null
        $lockPath=$target+'.wrapper-lock'
        $lock=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $temporary=$target+'.candidate-'+[guid]::NewGuid().ToString('N')
        try{
            New-GuideFile $temporary $CandidateContent
            $checked=Resolve-GuideWorkspacePath $WorkspaceRoot $RelativePath
            Assert-GuideWriteAllowed $Policy $RelativePath
            if($exists){
                if(-not [IO.File]::Exists($checked) -or (Get-FileHash -LiteralPath $checked).Hash -ine $ExpectedSha256){throw 'Wrapper file changed during preparation; candidate not applied.'}
                [IO.File]::Replace($temporary,$checked,[System.Management.Automation.Language.NullString]::Value)
            }else{[IO.File]::Move($temporary,$checked)}
        }finally{
            try{if([IO.File]::Exists($temporary)){[IO.File]::Delete($temporary)}}finally{$lock.Dispose();[IO.File]::Delete($lockPath)}
        }
        [pscustomobject]@{Status=if($exists){'updated'}else{'created'};Path=$RelativePath;Sha256=$digest;Language=$Language;ReadinessRequiresPrepare=$true}
    }
}