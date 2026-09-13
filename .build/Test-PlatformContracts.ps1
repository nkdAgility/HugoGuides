#Requires -Version 7.4
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$schemas = Join-Path $root 'system/OpenGuidePlatform.PowerShell.Core/Contracts'
$fixtures = Join-Path $root 'tests/Contracts/fixtures'
$count = 0
function Assert-Contract {
    param([string]$Name,[string]$Schema,[hashtable]$Value,[bool]$Expected)
    $valid = $Value | ConvertTo-Json -Depth 40 | Test-Json -SchemaFile (Join-Path $schemas "$Schema.schema.json") -ErrorAction SilentlyContinue
    if ($valid -ne $Expected) { throw "$Name : expected valid=$Expected; observed $valid" }
    $script:count++
    Write-Host "PASS $Name"
}
function Read-Fixture([string]$Name) { Get-Content -Raw (Join-Path $fixtures "$Name.json") | ConvertFrom-Json -AsHashtable }
foreach ($name in @('single-guide','two-guide','many-guide')) {
    Assert-Contract "$name policy" 'site-policy' (Read-Fixture "$name.site-policy") $true
}
Assert-Contract 'blocked assessment is actionable' 'assessment' (Read-Fixture 'blocked.assessment') $true
Assert-Contract 'immutable preview lock' 'platform-lock' (Read-Fixture 'preview.platform-lock') $true
$x=Read-Fixture 'blocked.assessment'; $x.outcome='pass'
Assert-Contract 'blockers cannot be reported as pass' 'assessment' $x $false
$x=Read-Fixture 'two-guide.site-policy'; $x.guides[0].editions[0].translations[1].Remove('fallbackLanguage') | Out-Null
Assert-Contract 'fallback must name its source language' 'site-policy' $x $false
$x=Read-Fixture 'single-guide.site-policy'; $x.guides[0].contentRoot='../outside'
Assert-Contract 'parent traversal rejected' 'site-policy' $x $false
$x=Read-Fixture 'single-guide.site-policy'; $x.guides[0].contentRoot='C:/outside'
Assert-Contract 'absolute drive path rejected' 'site-policy' $x $false
$x=Read-Fixture 'single-guide.site-policy'; $x.guides[0].contentRoot='site/../../outside'
Assert-Contract 'nested traversal rejected' 'site-policy' $x $false
$x=Read-Fixture 'single-guide.site-policy'; $x.guides=@()
Assert-Contract 'a site must wrap at least one guide' 'site-policy' $x $false
$x=Read-Fixture 'single-guide.site-policy'; $x.maintainer=$true
Assert-Contract 'candidate policy cannot add an authority field' 'site-policy' $x $false
$x=Read-Fixture 'preview.platform-lock'; $x.workflow.commit='main'
Assert-Contract 'invalid workflow source provenance rejected' 'platform-lock' $x $false
$x=Read-Fixture 'preview.platform-lock'; $x.hugoModule.version='latest'
Assert-Contract 'floating Hugo dependency rejected' 'platform-lock' $x $false
$x=Read-Fixture 'single-guide.site-policy'; $x.guides[0].editions[0].translations[0].intent='ready'
Assert-Contract 'readiness is not publication intent' 'site-policy' $x $false
$x=Read-Fixture 'many-guide.site-policy'; $extension=$x.guides | Where-Object { $_.relationship.kind -eq 'extension' } | Select-Object -First 1; $extension.relationship.Remove('parentGuideId') | Out-Null
Assert-Contract 'extension must name its parent guide' 'site-policy' $x $false
$x=Read-Fixture 'single-guide.site-policy'; $x.guides[0].editions[0].translations[0].intent='pdf-only'
Assert-Contract 'PDF-only with supplied resource is valid' 'site-policy' $x $true
$x.guides[0].editions[0].translations[0].downloads=@()
Assert-Contract 'PDF-only requires a declared download' 'site-policy' $x $false
$x=Read-Fixture 'single-guide.site-policy'
$prototype=$x.guides[0] | ConvertTo-Json -Depth 30
$x.guides=@(1..128 | ForEach-Object { $g=$prototype|ConvertFrom-Json -AsHashtable; $g.id="synthetic-guide-$_"; $g.contentRoot="site/content/synthetic-guide-$_"; $g })
Assert-Contract 'guide collection is not limited to existing consumer counts' 'site-policy' $x $true
Write-Host "$count contract checks passed. These are structural checks; trusted policy enforcement is E06."

foreach($version in @('v1','v1.2','v1.2.3','v1.2.3-Preview.4')) {
    $x=Read-Fixture 'preview.platform-lock';$x.workflow.version=$version
    Assert-Contract "version-tag workflow reference $version accepted" 'platform-lock' $x $true
}
foreach($version in @('main',('a'*40))) {
    $x=Read-Fixture 'preview.platform-lock';$x.workflow.version=$version
    Assert-Contract "non-version workflow reference rejected" 'platform-lock' $x $false
}
$x=Read-Fixture 'preview.platform-lock';$x.workflow.Remove('version')|Out-Null
Assert-Contract 'workflow version reference is required separately from source provenance' 'platform-lock' $x $false
Write-Host "$count total contract checks passed."