#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Compare two Hugo i18n YAML files and identify missing translation keys.

.DESCRIPTION
    This script compares two YAML translation files and identifies keys that exist in the source
    but are missing in the target. It can optionally add the missing keys to the target file.

.PARAMETER SourceFile
    Path to the source YAML file (contains the keys you want to port)

.PARAMETER TargetFile
    Path to the target YAML file (file to be updated)

.PARAMETER AddMissing
    Switch to automatically add missing keys to the target file

.PARAMETER WhatIf
    Show what would be added without actually modifying the target file

.EXAMPLE
    .\Compare-YamlTranslations.ps1 -SourceFile "module\i18n\en.yaml" -TargetFile "site\i18n\en.yaml"
    
.EXAMPLE
    .\Compare-YamlTranslations.ps1 -SourceFile "module\i18n\en.yaml" -TargetFile "site\i18n\en.yaml" -AddMissing
    
.EXAMPLE
    .\Compare-YamlTranslations.ps1 -SourceFile "module\i18n\en.yaml" -TargetFile "site\i18n\en.yaml" -AddMissing -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFile,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetFile,
    
    [Parameter(Mandatory = $false)]
    [switch]$AddMissing,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Function to parse YAML translation file and extract key-value pairs
function Parse-YamlTranslations {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $content = Get-Content $FilePath -Raw
    $translations = @{}
    $currentEntry = @{}
    
    # Split content into lines and process
    $lines = $content -split "`n"
    
    foreach ($line in $lines) {
        $line = $line.Trim()
        
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }
        
        # Check for new entry (starts with - id:)
        if ($line -match '^-\s+id:\s*(.+)$') {
            # Save previous entry if it exists
            if ($currentEntry.id -and $currentEntry.translation) {
                $translations[$currentEntry.id] = $currentEntry.translation
            }
            
            # Start new entry
            $currentEntry = @{
                id          = $matches[1].Trim('"').Trim("'")
                translation = $null
            }
        }
        # Check for translation line
        elseif ($line -match '^translation:\s*(.+)$') {
            if ($currentEntry.id) {
                $translationValue = $matches[1].Trim()
                # Remove surrounding quotes if present
                if (($translationValue.StartsWith('"') -and $translationValue.EndsWith('"')) -or
                    ($translationValue.StartsWith("'") -and $translationValue.EndsWith("'"))) {
                    $translationValue = $translationValue.Substring(1, $translationValue.Length - 2)
                }
                $currentEntry.translation = $translationValue
            }
        }
    }
    
    # Don't forget the last entry
    if ($currentEntry.id -and $currentEntry.translation) {
        $translations[$currentEntry.id] = $currentEntry.translation
    }
    
    return $translations
}

# Function to format YAML entry
function Format-YamlEntry {
    param(
        [string]$Id,
        [string]$Translation
    )
    
    # Escape translation value if it contains special characters
    $escapedTranslation = $Translation
    if ($Translation -match '[:"''\\]' -or $Translation.Contains('{{') -or $Translation.Contains('}}')) {
        $escapedTranslation = '"' + $Translation.Replace('\', '\\').Replace('"', '\"') + '"'
    }
    else {
        $escapedTranslation = '"' + $Translation + '"'
    }
    
    return @"
- id: $Id
  translation: $escapedTranslation

"@
}

try {
    Write-Host "🔍 Comparing YAML translation files..." -ForegroundColor Cyan
    Write-Host "Source: $SourceFile" -ForegroundColor Gray
    Write-Host "Target: $TargetFile" -ForegroundColor Gray
    Write-Host ""
    
    # Parse both files
    Write-Host "📖 Parsing source file..." -ForegroundColor Yellow
    $sourceTranslations = Parse-YamlTranslations -FilePath $SourceFile
    Write-Host "   Found $($sourceTranslations.Count) translation keys" -ForegroundColor Green
    
    Write-Host "📖 Parsing target file..." -ForegroundColor Yellow
    $targetTranslations = Parse-YamlTranslations -FilePath $TargetFile
    Write-Host "   Found $($targetTranslations.Count) translation keys" -ForegroundColor Green
    Write-Host ""
    
    # Find missing keys
    $missingKeys = @()
    $duplicateKeys = @()
    $differentValues = @()
    
    foreach ($sourceKey in $sourceTranslations.Keys) {
        if (-not $targetTranslations.ContainsKey($sourceKey)) {
            $missingKeys += $sourceKey
        }
        elseif ($targetTranslations[$sourceKey] -ne $sourceTranslations[$sourceKey]) {
            $differentValues += $sourceKey
        }
    }
    
    # Find keys that exist in target but not in source (potential duplicates or extras)
    foreach ($targetKey in $targetTranslations.Keys) {
        if (-not $sourceTranslations.ContainsKey($targetKey)) {
            $duplicateKeys += $targetKey
        }
    }
    
    # Display results
    Write-Host "📊 Comparison Results:" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    
    if ($missingKeys.Count -gt 0) {
        Write-Host "❌ Missing keys in target ($($missingKeys.Count)):" -ForegroundColor Red
        foreach ($key in $missingKeys | Sort-Object) {
            Write-Host "   - $key" -ForegroundColor Red
            Write-Host "     Value: $($sourceTranslations[$key])" -ForegroundColor Gray
        }
        Write-Host ""
    }
    else {
        Write-Host "✅ No missing keys found!" -ForegroundColor Green
        Write-Host ""
    }
    
    if ($differentValues.Count -gt 0) {
        Write-Host "⚠️  Keys with different values ($($differentValues.Count)):" -ForegroundColor Yellow
        foreach ($key in $differentValues | Sort-Object) {
            Write-Host "   - $key" -ForegroundColor Yellow
            Write-Host "     Source: $($sourceTranslations[$key])" -ForegroundColor Gray
            Write-Host "     Target: $($targetTranslations[$key])" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    if ($duplicateKeys.Count -gt 0) {
        Write-Host "ℹ️  Keys only in target ($($duplicateKeys.Count)):" -ForegroundColor Blue
        foreach ($key in $duplicateKeys | Sort-Object) {
            Write-Host "   - $key" -ForegroundColor Blue
        }
        Write-Host ""
    }
    
    # Add missing keys if requested
    if ($AddMissing -and $missingKeys.Count -gt 0) {
        if ($WhatIf) {
            Write-Host "🔍 What would be added to target file:" -ForegroundColor Cyan
            foreach ($key in $missingKeys | Sort-Object) {
                $entry = Format-YamlEntry -Id $key -Translation $sourceTranslations[$key]
                Write-Host $entry -ForegroundColor Green
            }
        }
        else {
            Write-Host "➕ Adding missing keys to target file..." -ForegroundColor Green
            
            # Read current target content
            $targetContent = Get-Content $TargetFile -Raw
            
            # Add missing entries at the end
            $newEntries = ""
            foreach ($key in $missingKeys | Sort-Object) {
                $newEntries += Format-YamlEntry -Id $key -Translation $sourceTranslations[$key]
            }
            
            # Ensure there's a newline before adding new content
            if (-not $targetContent.EndsWith("`n")) {
                $targetContent += "`n"
            }
            
            # Add the new entries
            $updatedContent = $targetContent + $newEntries
            
            # Write back to file
            Set-Content -Path $TargetFile -Value $updatedContent -NoNewline
            
            Write-Host "✅ Successfully added $($missingKeys.Count) missing keys to $TargetFile" -ForegroundColor Green
        }
    }
    elseif ($missingKeys.Count -gt 0) {
        Write-Host "💡 To add missing keys automatically, use the -AddMissing parameter" -ForegroundColor Cyan
        Write-Host "💡 To see what would be added without making changes, use -AddMissing -WhatIf" -ForegroundColor Cyan
    }
    
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
