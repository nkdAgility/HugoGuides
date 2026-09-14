#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1') -Force
$relative='.processing/i18n-integration-'+[guid]::NewGuid().ToString('N')
$fixture=Join-Path $root $relative
function Write-Fixture($path,$text){[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))|Out-Null;[IO.File]::WriteAllText($path,$text)}
$source=Join-Path $fixture 'site'
$catalogues=Join-Path $fixture 'catalogues'
Write-Fixture (Join-Path $catalogues 'go.mod') "module example.org/probe/catalogues`n`ngo 1.24.4`n"
$replacement=$catalogues.Replace('\','/')
Write-Fixture (Join-Path $source 'go.mod') "module example.org/probe/site`n`ngo 1.24.4`n`nrequire example.org/probe/catalogues v0.0.0`nreplace example.org/probe/catalogues => `"$replacement`"`n"
$config=@{baseURL='https://example.invalid/';defaultContentLanguage='en';languages=@{en=@{weight=1};fa=@{weight=2};'es-419'=@{weight=3}};module=@{imports=@(@{path='example.org/probe/catalogues'})}}
Write-Fixture (Join-Path $source 'hugo.json') ($config|ConvertTo-Json -Depth 20)
Write-Fixture (Join-Path $source 'i18n/en.yaml') "- id: home`n  translation: Wrapper home`n"
Write-Fixture (Join-Path $source 'i18n/fa.yaml') "- id: home`n  translation: خانه`n"
Write-Fixture (Join-Path $catalogues 'i18n/en.yaml') "- id: home`n  translation: Module home`n- id: module_only`n  translation: English module`n- id: fallback`n  translation: English fallback`n"
Write-Fixture (Join-Path $catalogues 'i18n/fa.yaml') "- id: module_only`n  translation: پیام ماژول`n"
$hash=(Get-FileHash (Join-Path $source 'go.mod')).Hash
$result=Get-GuideEffectiveTranslations -SourcePath $source -ConfigFiles @('hugo.json') -RequiredKeys @('home','module_only','fallback','missing') -WorkspaceRoot $root -OutputPath "$relative/evidence" -Target preview
$fa=$result.Languages|Where-Object Language -EQ fa
$en=$result.Languages|Where-Object Language -EQ en
$regional=$result.Languages|Where-Object Language -EQ es-419
if(($fa.Keys|Where-Object Key -EQ home).Value -cne 'خانه'){throw 'Wrapper Persian translation was not used.'}
if(($fa.Keys|Where-Object Key -EQ module_only).Value -cne 'پیام ماژول'){throw 'Mounted module Persian translation was not used.'}
if(($fa.Keys|Where-Object Key -EQ fallback).State -ne 'fallback'){throw 'Default-language fallback was not identified.'}
if(($en.Keys|Where-Object Key -EQ home).Value -cne 'Wrapper home'){throw 'Wrapper override precedence changed.'}
if(($regional.Keys|Where-Object Key -EQ home).Value -cne 'Wrapper home' -or ($regional.Keys|Where-Object Key -EQ home).State -notin @('available','fallback')){throw 'Numeric-region resolution was not observed.'}
if(($fa.Keys|Where-Object Key -EQ missing).State -ne 'missing'){throw 'Missing translation was not identified.'}
if((Get-FileHash (Join-Path $source 'go.mod')).Hash -cne $hash){throw 'Translation probe changed the module pin.'}
Write-Host 'PASS Hugo translation probe: wrapper override, module catalogue, Persian, numeric region, fallback, missing key and unchanged pin.'