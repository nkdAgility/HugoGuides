#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ArtifactRoot,[Parameter(Mandatory)][uri]$BaseUri,[object[]]$RequiredPageContent=@())
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($ArtifactRoot)
$files=@(Get-ChildItem -LiteralPath $root -Recurse -File -Force)
$paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach($file in $files){$null=$paths.Add([IO.Path]::GetRelativePath($root,$file.FullName).Replace('\','/'))}
$findings=[Collections.Generic.List[object]]::new()
$checked=0
$anchorsChecked=0
$anchorCache=@{}
function Get-PageAnchors([string]$RelativePath){
    if(-not $anchorCache.ContainsKey($RelativePath)){
        $ids=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $document=[IO.File]::ReadAllText((Join-Path $root $RelativePath))
        # Read complete attribute tokens so data-id, form names and text inside another
        # attribute cannot masquerade as fragment targets. Ignore inert comment/script text.
        $tagPattern='(?is)<!--.*?-->|<(?:script|style)\b[^>]*>.*?</(?:script|style)\s*>|<(?<tag>[a-z][a-z0-9:-]*)(?<attributes>(?:[^>"'']|"[^"]*"|''[^'']*'')*)>'
        $attributePattern='(?s)(?:^|\s)(?<name>[^\s=/>]+)(?:\s*=\s*(?:"(?<value>[^"]*)"|''(?<value>[^'']*)''|(?<value>[^\s>]+)))?'
        foreach($tag in [regex]::Matches($document,$tagPattern)){
            if(-not $tag.Groups['tag'].Success){continue}
            foreach($attribute in [regex]::Matches($tag.Groups['attributes'].Value,$attributePattern)){
                $name=$attribute.Groups['name'].Value
                if($name -ieq 'id' -or ($name -ieq 'name' -and $tag.Groups['tag'].Value -ieq 'a')){
                    $null=$ids.Add([Net.WebUtility]::HtmlDecode($attribute.Groups['value'].Value))
                }
            }
        }
        $anchorCache[$RelativePath]=$ids
    }
    return ,$anchorCache[$RelativePath]
}
foreach($file in $files|Where-Object Extension -EQ '.html'){
    $relative=[IO.Path]::GetRelativePath($root,$file.FullName).Replace('\','/')
    $page=[uri]::new($BaseUri,$relative)
    $html=[IO.File]::ReadAllText($file.FullName)
    foreach($match in [regex]::Matches($html,'(?is)<(?:a|link|script|img)\b[^>]*?\b(?:href|src)\s*=\s*(?:"([^"]*)"|''([^'']*)''|([^\s>]+))')){
        $value=($match.Groups[1..3]|Where-Object Success|Select-Object -First 1).Value
        $value=[Net.WebUtility]::HtmlDecode($value)
        if(-not $value){continue}
        $uri=$null
        if(-not [uri]::TryCreate($page,$value,[ref]$uri) -or $uri.Scheme -notin @('https','http') -or $uri.Authority -cne $BaseUri.Authority){continue}
        $path=[uri]::UnescapeDataString($uri.AbsolutePath).TrimStart('/')
        $candidates=@($path,($path.TrimEnd('/')+'/index.html'))
        if(-not $path){$candidates=@('index.html')}
        $checked++
        $found=@($candidates|Where-Object {$paths.Contains($_)})
        if(-not $found.Count){
            $findings.Add([pscustomobject]@{Code='INTERNAL_LINK_MISSING';Page=$relative;Target=$value})
        }elseif($uri.Fragment -and [IO.Path]::GetExtension($found[0]) -eq '.html'){
            # Empty/top and text-fragment navigation do not require an element ID.
            $fragment=[uri]::UnescapeDataString($uri.Fragment.Substring(1)).Split(':~:',2)[0]
            if($fragment -and $fragment -ine 'top'){
                $anchorsChecked++
                $anchors=Get-PageAnchors $found[0]
                if(-not $anchors.Contains($fragment)){
                    $findings.Add([pscustomobject]@{Code='INTERNAL_ANCHOR_MISSING';Page=$relative;Target=$value})
                }
            }
        }
    }
}
foreach($expectation in $RequiredPageContent){
    $route=[string]$expectation.route
    if(-not $route.StartsWith('/') -or $route -match '(^//|\\|:|[?#%]|(^|/)\.\.(/|$))'){throw "Unsafe expected-content route: $route"}
    $path=$route.Trim('/')
    $candidates=if($path){@($path,($path+'/index.html'))}else{@('index.html')}
    $found=@($candidates|Where-Object {$paths.Contains($_)})
    $text=if($found.Count){[Net.WebUtility]::HtmlDecode(([IO.File]::ReadAllText((Join-Path $root $found[0])) -replace '<[^>]+>',' '))}else{''}
    if(-not $text.Contains([string]$expectation.text)){
        $findings.Add([pscustomobject]@{Code='REQUIRED_PAGE_CONTENT_MISSING';Page=$route;Target=[string]$expectation.text})
    }
}
[pscustomobject]@{Outcome=if($findings.Count){'fail'}else{'pass'};Pages=@($files|Where-Object Extension -EQ '.html').Count;Links=$checked;Anchors=$anchorsChecked;Findings=$findings.ToArray()}
