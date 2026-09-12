#Requires -Version 7.4
<#
.SYNOPSIS
Records declared guide structure and effective Hugo language configuration from archived baselines.
.DESCRIPTION
Readiness is not inferred from body length or file presence. Existing publication behavior
is evidenced separately by rendered routes. Run against Measure-ConsumerBaseline output.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselinePath,
    [Parameter(Mandatory)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module powershell-yaml -RequiredVersion 0.4.12
$baseline = Get-Content -Raw (Join-Path $BaselinePath 'baseline.json') | ConvertFrom-Json
if (Test-Path -LiteralPath $OutputPath) { throw 'Use a new output path to preserve earlier evidence.' }
$records = foreach ($repository in $baseline.repositories) {
    $snapshot = Join-Path $BaselinePath $repository.repository
    $site = Join-Path $snapshot 'site'
    $configurations = foreach ($ring in @('local','preview','production')) {
        $environment = if ($ring -eq 'local') { 'development' } else { $ring }
        $raw = & hugo config --source $site --config "hugo.yaml,hugo.$ring.yaml" --environment $environment --format json
        if ($LASTEXITCODE -ne 0) { throw "Effective config failed: $($repository.repository) $ring" }
        $effective = ($raw | Out-String) | ConvertFrom-Json -AsHashtable
        [ordered]@{ring=$ring;defaultLanguage=$effective.defaultcontentlanguage;languages=$effective.languages}
    }
    $source = foreach ($file in Get-ChildItem (Join-Path $site 'content') -Recurse -File -Filter '*.md' | Sort-Object FullName) {
        $text = Get-Content -Raw -LiteralPath $file.FullName
        $match = [regex]::Match($text,'\A---\r?\n(?<metadata>.*?)\r?\n---(?:\r?\n|\z)(?<body>.*)\z',[Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $match.Success) { throw "Unrecognised front matter: $($file.FullName)" }
        $metadata = ConvertFrom-Yaml $match.Groups['metadata'].Value
        $language = $configurations[0].defaultLanguage
        if ($file.BaseName -match '^(?:_?index)\.(?<language>.+)$') { $language = $Matches.language }
        $selected = [ordered]@{}
        foreach ($key in @('type','layout','title','slug','url','aliases','date','draft','version','latest','guide','cascade','build','_build','direction','translationKey')) {
            if ($metadata.ContainsKey($key)) { $selected[$key]=$metadata[$key] }
        }
        [ordered]@{
            path=[IO.Path]::GetRelativePath($site,$file.FullName).Replace('\','/')
            filenameLanguage=$language
            bodyHasNonWhitespace= -not [string]::IsNullOrWhiteSpace($match.Groups['body'].Value)
            declarations=$selected
        }
    }
    [ordered]@{repository=$repository.repository;commit=$repository.commit;configurations=@($configurations);source=@($source)}
}
[ordered]@{
    schemaVersion=1
    scope='Declared source structure and effective language configuration; presence is not translation or publication approval.'
    parser='powershell-yaml 0.4.12'
    repositories=@($records)
} | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $OutputPath
