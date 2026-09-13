#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ArtifactRoot,[Parameter(Mandatory)][uri]$BaseUri)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($ArtifactRoot)
$files=@(Get-ChildItem -LiteralPath $root -Recurse -File -Force)
$paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach($file in $files){$null=$paths.Add([IO.Path]::GetRelativePath($root,$file.FullName).Replace('\','/'))}
$findings=[Collections.Generic.List[object]]::new()
$checked=0
foreach($file in $files|Where-Object Extension -EQ '.html'){
    $relative=[IO.Path]::GetRelativePath($root,$file.FullName).Replace('\','/')
    $page=[uri]::new($BaseUri,$relative)
    $html=[IO.File]::ReadAllText($file.FullName)
    foreach($match in [regex]::Matches($html,'(?is)<(?:a|link|script|img)\b[^>]*?\b(?:href|src)\s*=\s*(?:"([^"]*)"|''([^'']*)''|([^\s>]+))')){
        $value=($match.Groups[1..3]|Where-Object Success|Select-Object -First 1).Value
        $value=[Net.WebUtility]::HtmlDecode($value)
        if(-not $value -or $value.StartsWith('#')){continue}
        $uri=$null
        if(-not [uri]::TryCreate($page,$value,[ref]$uri) -or $uri.Scheme -notin @('https','http') -or $uri.Authority -cne $BaseUri.Authority){continue}
        $path=[uri]::UnescapeDataString($uri.AbsolutePath).TrimStart('/')
        $candidates=@($path,($path.TrimEnd('/')+'/index.html'))
        if(-not $path){$candidates=@('index.html')}
        $checked++
        if(-not @($candidates|Where-Object {$paths.Contains($_)}).Count){
            $findings.Add([pscustomobject]@{Code='INTERNAL_LINK_MISSING';Page=$relative;Target=$value})
        }
    }
}
[pscustomobject]@{Outcome=if($findings.Count){'fail'}else{'pass'};Pages=@($files|Where-Object Extension -EQ '.html').Count;Links=$checked;Findings=$findings.ToArray()}
