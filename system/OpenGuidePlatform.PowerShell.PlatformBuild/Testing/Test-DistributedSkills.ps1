#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
Import-Module powershell-yaml -MinimumVersion 0.4.12
Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1') -Force
$expected=@('guide.contributions','guide.genpdfs','guide.gravatar','guide.historicalversion','guide.transcreate','guide.transreconcile','guide.transstatus')
$directory=Join-Path $root 'system/OpenGuidePlatform.Agents.Integration/skills'
$actual=@(Get-ChildItem $directory -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') })
if (@(Compare-Object $expected @($actual.Name)).Count) { throw 'Distributed skill identities differ from the seven retained names.' }
$commands=@(Get-Command -Module OpenGuidePlatform.PowerShell.Core | Select-Object -ExpandProperty Name)
foreach($folder in $actual) {
    $text=Get-Content -Raw (Join-Path $folder.FullName 'SKILL.md')
    $match=[regex]::Match($text,'\A---\r?\n(?<yaml>.*?)\r?\n---\r?\n(?<body>.*)\z',[Text.RegularExpressions.RegexOptions]::Singleline)
    if(-not $match.Success){throw "Invalid skill front matter: $($folder.Name)"}
    $metadata=ConvertFrom-Yaml $match.Groups['yaml'].Value
    if($metadata.name -cne $folder.Name -or $metadata.name.Length -gt 64){throw 'Skill identity mismatch'}
    if([string]::IsNullOrWhiteSpace($metadata.description) -or $metadata.description.Length -gt 1024 -or $metadata.description -match '[<>]'){throw 'Invalid skill description'}
    if($text -match '\[TODO:'){throw 'Unfinished skill placeholder'}
    foreach($call in [regex]::Matches($text,'\b(?:Get|New|Import|Test|Update|Set)-Guide[A-Za-z]+\b')) { if($call.Value -notin $commands){throw "Skill refers to missing Core command: $($call.Value)"} }
    foreach($link in [regex]::Matches($text,'\]\((?<path>[^)]+)\)')) { if(-not (Test-Path (Join-Path $folder.FullName $link.Groups['path'].Value))){throw "Skill reference missing: $($link.Value)"} }
    Write-Host "PASS $($folder.Name) metadata, references and Core commands"
}
Write-Host 'The retained dotted names are intentional compatibility identities; the generic hyphen-only skill naming rule does not apply.'
