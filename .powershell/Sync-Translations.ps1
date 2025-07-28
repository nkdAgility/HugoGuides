#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick comparison script for Hugo i18n files in this project.

.DESCRIPTION
    This script provides an easy way to compare YAML translation files and sync missing translations between them.
    You can either use the default module/site files or specify custom source and target files.

.PARAMETER SourceFile
    Path to the source YAML file (contains the keys you want to port). If not specified, uses Direction parameter.

.PARAMETER TargetFile
    Path to the target YAML file (file to be updated). If not specified, uses Direction parameter.

.PARAMETER Direction
    Direction of sync when using default files: "ModuleToSite" (default) or "SiteToModule". Ignored if SourceFile and TargetFile are specified.

.PARAMETER AddMissing
    Switch to automatically add missing keys to the target file

.PARAMETER WhatIf
    Show what would be added without actually modifying the target file

.EXAMPLE
    .\Sync-Translations.ps1
    Compare module to site (default)
    
.EXAMPLE
    .\Sync-Translations.ps1 -AddMissing
    Add missing keys from module to site
    
.EXAMPLE
    .\Sync-Translations.ps1 -Direction SiteToModule -AddMissing -WhatIf
    Show what would be added from site to module

.EXAMPLE
    .\Sync-Translations.ps1 -SourceFile "custom\source.yaml" -TargetFile "custom\target.yaml" -AddMissing
    Compare custom files and add missing keys

.EXAMPLE
    .\Sync-Translations.ps1 -SourceFile "C:\full\path\to\master.yaml" -TargetFile ".\local.yaml" -WhatIf
    Preview what would be added from a custom source to local target
#>

[CmdletBinding(DefaultParameterSetName = "DefaultFiles")]
param(
    [Parameter(Mandatory = $false, ParameterSetName = "CustomFiles")]
    [string]$SourceFile,
    
    [Parameter(Mandatory = $false, ParameterSetName = "CustomFiles")]
    [string]$TargetFile,
    
    [Parameter(Mandatory = $false, ParameterSetName = "DefaultFiles")]
    [ValidateSet("ModuleToSite", "SiteToModule")]
    [string]$Direction = "ModuleToSite",
    
    [Parameter(Mandatory = $false)]
    [switch]$AddMissing,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Get the script directory (should be .powershell folder)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Determine source and target files
if ($PSCmdlet.ParameterSetName -eq "CustomFiles") {
    # Custom files specified
    if ([string]::IsNullOrWhiteSpace($SourceFile) -or [string]::IsNullOrWhiteSpace($TargetFile)) {
        Write-Error "When using custom files, both SourceFile and TargetFile must be specified."
        exit 1
    }
    
    # Convert relative paths to absolute paths
    if (-not [System.IO.Path]::IsPathRooted($SourceFile)) {
        $SourceFile = Join-Path $ProjectRoot $SourceFile
    }
    if (-not [System.IO.Path]::IsPathRooted($TargetFile)) {
        $TargetFile = Join-Path $ProjectRoot $TargetFile
    }
    
    Write-Host "🔄 Syncing translations from CUSTOM SOURCE → CUSTOM TARGET" -ForegroundColor Cyan
    Write-Host "   Source: $SourceFile" -ForegroundColor Gray
    Write-Host "   Target: $TargetFile" -ForegroundColor Gray
} else {
    # Default files based on Direction
    $ModuleFile = Join-Path $ProjectRoot "module\i18n\en.yaml"
    $SiteFile = Join-Path $ProjectRoot "site\i18n\en.yaml"
    
    # Verify default files exist
    if (-not (Test-Path $ModuleFile)) {
        Write-Error "Module file not found: $ModuleFile"
        exit 1
    }
    
    if (-not (Test-Path $SiteFile)) {
        Write-Error "Site file not found: $SiteFile"
        exit 1
    }
    
    # Set source and target based on direction
    if ($Direction -eq "ModuleToSite") {
        $SourceFile = $ModuleFile
        $TargetFile = $SiteFile
        Write-Host "🔄 Syncing translations from MODULE → SITE" -ForegroundColor Cyan
    } else {
        $SourceFile = $SiteFile
        $TargetFile = $ModuleFile
        Write-Host "🔄 Syncing translations from SITE → MODULE" -ForegroundColor Cyan
    }
}

# Verify files exist
if (-not (Test-Path $SourceFile)) {
    Write-Error "Source file not found: $SourceFile"
    exit 1
}

if (-not (Test-Path $TargetFile)) {
    Write-Error "Target file not found: $TargetFile"
    exit 1
}

Write-Host ""

# Call the main comparison script
$CompareScript = Join-Path $ScriptDir "Compare-YamlTranslations.ps1"
$params = @{
    SourceFile = $SourceFile
    TargetFile = $TargetFile
}

if ($AddMissing) {
    $params.AddMissing = $true
}

if ($WhatIf) {
    $params.WhatIf = $true
}

& $CompareScript @params
