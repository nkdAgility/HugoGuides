function Test-GuideJsonIndexes {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ArtifactRoot,[Parameter(Mandatory)][uri]$BaseUri,[object[]]$Indexes=@(),[string[]]$EnabledLanguages=@(),[string[]]$ForbiddenPaths=@())
    $siteBase=[uri]($BaseUri.GetLeftPart([UriPartial]::Path).TrimEnd('/')+'/')
    $files=@(Get-GuideArtifactFiles $ArtifactRoot)
    $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($file in $files){$null=$paths.Add($file.Path)}
    $findings=[Collections.Generic.List[object]]::new();$checked=0
    foreach($index in $Indexes){
        try{
            $candidates=@(Get-GuideArtifactRouteCandidates $index.route)
            $file=@($files|Where-Object Path -CIn $candidates)
            if($file.Count -ne 1){throw 'Declared JSON index is missing.'}
            $data=Get-Content -LiteralPath $file[0].FullName -Raw|ConvertFrom-Json -AsHashtable -NoEnumerate -ErrorAction Stop
            if($null -eq $data -or $data -is [string] -or $data -is [ValueType]){throw 'A JSON index must contain an object or array.'}
            $observed=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            function Read-IndexNode($node){
                if($node -is [Collections.IDictionary]){
                    foreach($key in $node.Keys){
                        $value=$node[$key]
                        if($key -in @('url','RelPermalink','Permalink','PathPdf') -and $value -is [string] -and $value){
                            $url=$null
                            if(-not [uri]::TryCreate($siteBase,$value,[ref]$url) -or $url.Scheme -notin @('http','https')){$findings.Add([pscustomobject]@{Code='JSON_INDEX_URL_INVALID';Path=$index.route;Message="Repair invalid indexed URL $value"});continue}
                            $route=Get-GuideArtifactRouteFromUri -Uri $url -BaseUri $BaseUri
                            if($null -ne $route){
                                $targets=@(Get-GuideArtifactRouteCandidates $route)
                                $route=[uri]::UnescapeDataString($route)
                                $null=$observed.Add($route)
                                if(-not @($targets|Where-Object {$paths.Contains($_)}).Count){$findings.Add([pscustomobject]@{Code='JSON_INDEX_TARGET_MISSING';Path=$index.route;Message="Repair missing indexed target $route"})}
                                $relative=$route.TrimStart('/')
                                if(@($ForbiddenPaths|Where-Object {$relative -ceq $_.TrimEnd('/') -or $relative.StartsWith($_.TrimEnd('/')+'/',[StringComparison]::Ordinal)}).Count){$findings.Add([pscustomobject]@{Code='JSON_INDEX_FORBIDDEN_TARGET';Path=$index.route;Message="Remove prohibited indexed target $route"})}
                            }
                        }
                        Read-IndexNode $value
                    }
                }elseif($node -is [Collections.IEnumerable] -and $node -isnot [string]){foreach($item in $node){Read-IndexNode $item}}
            }
            Read-IndexNode $data
            foreach($route in $index.requiredRoutes){if(-not $observed.Contains($route)){$findings.Add([pscustomobject]@{Code='JSON_INDEX_ENTRY_MISSING';Path=$index.route;Message="Restore required index entry $route"})}}
            if($data -is [Collections.IDictionary] -and $data.Contains('languages')){
                $codes=@($data.languages|ForEach-Object {$_['code']})
                if($codes.Count -ne $EnabledLanguages.Count -or @($codes|Select-Object -Unique).Count -ne $codes.Count -or @($EnabledLanguages|Where-Object {$_ -cnotin $codes}).Count){$findings.Add([pscustomobject]@{Code='JSON_INDEX_LANGUAGES_DIFFER';Path=$index.route;Message='Language catalogue differs from the enabled languages assessed by Prepare.'})}
                if($data.Contains('totalEnabledLanguages') -and $data.totalEnabledLanguages -ne $codes.Count){$findings.Add([pscustomobject]@{Code='JSON_INDEX_LANGUAGE_COUNT';Path=$index.route;Message='Correct the enabled language count.'})}
            }
            $checked++
        }catch{$findings.Add([pscustomobject]@{Code='JSON_INDEX_INVALID';Path=$index.route;Message=$_.Exception.Message})}
    }
    [pscustomobject]@{Outcome=if($findings.Count){'fail'}else{'pass'};Indexes=$checked;Findings=$findings.ToArray()}
}
