function Get-GuideJsonFileNames {
    param([Collections.IDictionary]$Configuration)
    @($Configuration.outputformats.Values|Where-Object {$_.mediatype -match 'json'}|ForEach-Object {
        $format=$_
        $media=$Configuration.mediatypes[$format.mediatype]
        $delimiter=if($media.Contains('delimiter')){[string]$media.delimiter}else{'.'}
        foreach($suffix in $media.suffixes){$format.basename+$delimiter+$suffix}
    }|Select-Object -Unique)
}
function Get-GuidePublishedDownloads {
    param([object[]]$ArtifactFiles,[uri]$BaseUri,[object[]]$Indexes=@())
    function Read-DownloadNode($node){
        if($node -is [Collections.IDictionary]){
            if($node.Contains('PathPdf') -and $node.PathPdf -and $node.Contains('Language') -and $node.Contains('VersionPath')){
                $url=$null
                if([uri]::TryCreate($BaseUri,[string]$node.PathPdf,[ref]$url)){
                    $route=Get-GuideArtifactRouteFromUri -Uri $url -BaseUri $BaseUri
                    if($route){[pscustomobject]@{VersionPath=([string]$node.VersionPath).Trim('/');Language=[string]$node.Language;Path=[uri]::UnescapeDataString($route).TrimStart('/')}}
                }
            }
            foreach($value in $node.Values){Read-DownloadNode $value}
        }elseif($node -is [Collections.IEnumerable] -and $node -isnot [string]){foreach($value in $node){Read-DownloadNode $value}}
    }
    $expected=@($Indexes|ForEach-Object {Get-GuideArtifactRouteCandidates $_.route})
    foreach($file in $ArtifactFiles|Where-Object {$_.Path -cin $expected}){
        try{$data=Get-Content -LiteralPath $file.FullName -Raw|ConvertFrom-Json -AsHashtable -NoEnumerate -ErrorAction Stop}catch{continue} # JSON validation reports malformed indexes.
        Read-DownloadNode $data
    }
}
