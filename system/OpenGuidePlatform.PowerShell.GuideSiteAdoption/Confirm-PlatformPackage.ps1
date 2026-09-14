#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageRoot,[Parameter(Mandatory)]$Manifest)
$ErrorActionPreference='Stop'
$metadata=Get-Content "$PackageRoot/platform.json" -Raw|ConvertFrom-Json
if($metadata.product -cne 'OpenGuidePlatform' -or $metadata.sourceCommit -cne $Manifest.sourceCommit -or $metadata.version -cne $Manifest.version){throw 'Installed platform identity mismatch.'}
$fields=$Manifest|ConvertTo-Json -Depth 20|ConvertFrom-Json -AsHashtable
foreach($field in @('nativeHugoModule','workflow','requirements')){
    $expected=$fields[$field]
    if($null -ne $expected -and ($metadata.$field|ConvertTo-Json -Depth 10 -Compress) -cne ($expected|ConvertTo-Json -Depth 10 -Compress)){throw "Package/manifest coordinated identity differs: $field"}
}
if($fields.schemaVersion -eq 2 -and $fields.packages.GuideSite.ContainsKey('components')){
    if(($metadata.components|ConvertTo-Json -Compress) -cne ($fields.packages.GuideSite.components|ConvertTo-Json -Compress)){throw 'GuideSite component inventory differs from the release.'}
}
return $metadata
