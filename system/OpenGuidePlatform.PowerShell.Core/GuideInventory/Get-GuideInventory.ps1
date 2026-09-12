function Get-GuideInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][System.Collections.IDictionary]$Policy)
    $guides=@(foreach ($guide in $Policy.guides) {
        $editions=@(foreach ($edition in $guide.editions) {
            $relative="$($guide.contentRoot)/$($edition.path)"
            $directory=Resolve-GuideWorkspacePath $WorkspaceRoot $relative
            $translations=@(foreach ($translation in $edition.translations) {
                $name=if($translation.language -eq $edition.sourceLanguage){'index.md'}else{"index.$($translation.language).md"}
                $path=Resolve-GuideWorkspacePath $WorkspaceRoot "$relative/$name"
                $body='missing';$frontMatterLang=$false
                if (Test-Path -LiteralPath $path -PathType Leaf) {
                    $document=Read-GuideDocument $path
                    $body=if([string]::IsNullOrWhiteSpace($document.Body)){'empty'}else{'populated'}
                    $frontMatterLang=$document.Metadata.Contains('lang')
                }
                $downloads=@(foreach($download in $translation.downloads){
                    $file=Resolve-GuideWorkspacePath $WorkspaceRoot "$relative/$($download.path)"
                    [pscustomobject]@{Path=$download.path;Handling=$download.handling;Exists=[IO.File]::Exists($file)}
                })
                $fallbackAvailable=$false
                if ($translation.intent -eq 'fallback') {
                    $fallbackName=if($translation.fallbackLanguage -eq $edition.sourceLanguage){'index.md'}else{"index.$($translation.fallbackLanguage).md"}
                    $fallbackPath=Resolve-GuideWorkspacePath $WorkspaceRoot "$relative/$fallbackName"
                    if ([IO.File]::Exists($fallbackPath)) { $fallbackAvailable= -not [string]::IsNullOrWhiteSpace((Read-GuideDocument $fallbackPath).Body) }
                }
                $state=Get-GuideTranslationState -Intent $translation.intent -Body $body -HasDownload (@($downloads|Where-Object Exists).Count -gt 0) -FallbackAvailable $fallbackAvailable
                [pscustomobject]@{Language=$translation.language;Intent=$translation.intent;Source="$relative/$name";State=$state.State;Body=$body;FindingCode=$state.FindingCode;DeprecatedLang=$frontMatterLang;Downloads=$downloads}
            })
            [pscustomobject]@{Id=$edition.id;SourceLanguage=$edition.sourceLanguage;Translations=$translations}
        })
        [pscustomobject]@{Id=$guide.id;Editions=$editions}
    })
    $wrapper=@(foreach($file in $Policy.wrapper.requiredFiles){$path=Resolve-GuideWorkspacePath $WorkspaceRoot $file;[pscustomobject]@{Path=$file;Exists=[IO.File]::Exists($path)}})
    [pscustomobject]@{SiteId=$Policy.siteId;Wrapper=[pscustomobject]@{Files=$wrapper;RequiredRoutes=@($Policy.wrapper.requiredRoutes);RequiredI18nKeys=@($Policy.wrapper.requiredI18nKeys)};Guides=$guides}
}
