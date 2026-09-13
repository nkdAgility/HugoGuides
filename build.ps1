#Requires -Version 7.4
[CmdletBinding()]
param([switch]$Versions,[ValidateSet('All','Prepare','Build','Validate')][string]$Stage='All',[ValidateSet('local','preview','production','canary')][string]$Target='local',[string]$OutputPath,[string]$Version='0.0.0-local')
$ErrorActionPreference='Stop'
if($Versions){
    "PowerShell $($PSVersionTable.PSVersion)"
    foreach($tool in @('hugo','go','pandoc','xelatex')){$command=Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1;if($command){"${tool}: $($command.Source)"}else{"${tool}: unavailable"}}
    return
}
if(-not $OutputPath){$OutputPath='.processing/platform-build/'+[guid]::NewGuid().ToString('N')} 
& (Join-Path $PSScriptRoot '.build/Invoke-PlatformBuild.ps1') -Stage $Stage -Target $Target -OutputPath $OutputPath -Version $Version