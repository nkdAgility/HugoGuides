function New-GuideTranslationScaffold {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][System.Collections.IDictionary]$Policy,[Parameter(Mandatory)][string]$GuideId,[Parameter(Mandatory)][string]$EditionId,[Parameter(Mandatory)][ValidatePattern('^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$')][string]$Language)
    $selection=Get-GuideSelection $Policy $GuideId $EditionId
    if ($Language -eq $selection.Edition.sourceLanguage) { throw 'Scaffolding must not overwrite the source language.' }
    $relative="$($selection.RelativePath)/index.$Language.md"
    $target=Resolve-GuideWorkspacePath $WorkspaceRoot $relative
    Assert-GuideWriteAllowed $Policy $relative
    if ([IO.File]::Exists($target)) { return [pscustomobject]@{Status='preserved';Path=$relative;ProductionChanged=$false} }
    # Require an explicit disabled entry before creating a language file. Never enable it here.
    $production=Resolve-GuideWorkspacePath $WorkspaceRoot "$($Policy.wrapper.sourcePath)/hugo.production.yaml"
    Import-Module powershell-yaml -RequiredVersion 0.4.12 -ErrorAction Stop
    $config=ConvertFrom-Yaml ([IO.File]::ReadAllText($production))
    if (-not $config.Contains('languages') -or -not $config.languages.Contains($Language) -or $config.languages[$Language]['disabled'] -ne $true) { throw "Declare $Language disabled in production configuration before scaffolding." }
    $source=Resolve-GuideWorkspacePath $WorkspaceRoot "$($selection.RelativePath)/index.md"
    $document=Read-GuideDocument $source
    $yaml=[regex]::Replace($document.Yaml,'(?m)^lang:\s*[^\r\n]*\r?\n?','')
    if ($PSCmdlet.ShouldProcess($target,'Create empty guide translation with unchanged source metadata and aliases')) { New-GuideFile $target "---`n$yaml`n---`n";return [pscustomobject]@{Status='created';Path=$relative;ProductionChanged=$false;NeedsMetadataTranslation=$true} }
}
