#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageRoot,[Parameter(Mandatory)]$Manifest)
$ErrorActionPreference='Stop'
$metadata=Get-Content "$PackageRoot/platform.json" -Raw|ConvertFrom-Json
if($metadata.product -cne 'OpenGuidePlatform' -or $metadata.sourceCommit -cne $Manifest.sourceCommit -or $metadata.version -cne $Manifest.version){throw 'Installed platform identity mismatch.'}
$fields=$Manifest|ConvertTo-Json -Depth 20|ConvertFrom-Json -AsHashtable
foreach($field in @('nativeHugoModule','workflow','components','requirements')){
    $expected=$fields[$field]
    if($null -ne $expected -and ($metadata.$field|ConvertTo-Json -Depth 10 -Compress) -cne ($expected|ConvertTo-Json -Depth 10 -Compress)){throw "Package/manifest coordinated identity differs: $field"}
}
return $metadata
