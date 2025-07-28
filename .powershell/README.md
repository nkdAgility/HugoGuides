# PowerShell Translation Tools

This folder contains PowerShell scripts to help manage Hugo i18n translation files.

## Scripts

### Compare-YamlTranslations.ps1

A comprehensive script that compares two YAML translation files and identifies:

- Missing keys in the target file
- Keys with different values between files
- Keys that exist only in the target file

**Usage:**

```powershell
# Basic comparison
.\Compare-YamlTranslations.ps1 -SourceFile "path\to\source.yaml" -TargetFile "path\to\target.yaml"

# Add missing keys to target file
.\Compare-YamlTranslations.ps1 -SourceFile "path\to\source.yaml" -TargetFile "path\to\target.yaml" -AddMissing

# Preview what would be added (dry run)
.\Compare-YamlTranslations.ps1 -SourceFile "path\to\source.yaml" -TargetFile "path\to\target.yaml" -AddMissing -WhatIf
```

### Sync-Translations.ps1

A convenient wrapper script that can either compare the default module and site en.yaml files or work with custom source and target files.

**Usage:**

```powershell
# Compare module to site translations (default)
.\Sync-Translations.ps1

# Add missing keys from module to site
.\Sync-Translations.ps1 -AddMissing

# Sync from site to module instead
.\Sync-Translations.ps1 -Direction SiteToModule -AddMissing

# Preview changes without making them
.\Sync-Translations.ps1 -AddMissing -WhatIf

# Compare custom files using relative paths
.\Sync-Translations.ps1 -SourceFile "custom\source.yaml" -TargetFile "custom\target.yaml"

# Compare custom files using absolute paths
.\Sync-Translations.ps1 -SourceFile "C:\path\to\master.yaml" -TargetFile "C:\path\to\local.yaml" -AddMissing

# Preview what would be added from custom source to target
.\Sync-Translations.ps1 -SourceFile "master.yaml" -TargetFile "local.yaml" -AddMissing -WhatIf
```

## Quick Start

1. **Compare default translations (module to site):**

   ```powershell
   cd .powershell
   .\Sync-Translations.ps1
   ```

2. **Add missing keys from module to site:**

   ```powershell
   .\Sync-Translations.ps1 -AddMissing
   ```

3. **Preview what would be added:**

   ```powershell
   .\Sync-Translations.ps1 -AddMissing -WhatIf
   ```

4. **Compare custom files:**

   ```powershell
   .\Sync-Translations.ps1 -SourceFile "path\to\source.yaml" -TargetFile "path\to\target.yaml"
   ```

## Features

- **Flexible File Selection**: Use default module/site files or specify custom source and target files
- **Safe Operations**: Use `-WhatIf` to preview changes before applying them
- **Bidirectional Sync**: Sync from module to site, site to module, or between any two YAML files
- **Path Flexibility**: Supports both relative and absolute file paths
- **Detailed Reporting**: Shows missing keys, different values, and extra keys
- **Proper YAML Formatting**: Maintains correct YAML structure and escaping
- **Error Handling**: Validates file existence and provides clear error messages

## File Structure

The scripts expect the following structure:

```text
project-root/
├── .powershell/
│   ├── Compare-YamlTranslations.ps1
│   ├── Sync-Translations.ps1
│   └── README.md
├── module/
│   └── i18n/
│       └── en.yaml
└── site/
    └── i18n/
        └── en.yaml
```

## Examples

### Typical Workflow

1. **Check what's missing:**

   ```powershell
   .\Sync-Translations.ps1
   ```

2. **Preview the additions:**

   ```powershell
   .\Sync-Translations.ps1 -AddMissing -WhatIf
   ```

3. **Apply the changes:**

   ```powershell
   .\Sync-Translations.ps1 -AddMissing
   ```

### Advanced Usage

Compare any two YAML files:

```powershell
.\Compare-YamlTranslations.ps1 -SourceFile "C:\path\to\master.yaml" -TargetFile "C:\path\to\local.yaml" -AddMissing
```

Or use the convenient wrapper:

```powershell
.\Sync-Translations.ps1 -SourceFile "master.yaml" -TargetFile "local.yaml" -AddMissing
```

**Working with different directories:**

```powershell
# Files in subdirectories (relative to project root)
.\Sync-Translations.ps1 -SourceFile "translations\master\en.yaml" -TargetFile "site\i18n\en.yaml"

# Absolute paths
.\Sync-Translations.ps1 -SourceFile "C:\translations\master.yaml" -TargetFile "C:\local\site.yaml"

# Mix of relative and absolute
.\Sync-Translations.ps1 -SourceFile "C:\shared\master.yaml" -TargetFile "local.yaml"
```

## Notes

- The scripts preserve the original formatting and structure of YAML files
- New entries are added at the end of the target file
- Translation values are properly escaped for special characters
- Comments and empty lines are preserved in the target file
