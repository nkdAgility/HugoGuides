function Get-GuideWrapperStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$WorkspaceRoot,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Policy,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Languages,
        [string[]]$ObservedRoutes,
        [object[]]$EffectiveTranslations,
        [string[]]$ObservedIntegrationPoints
    )
    # Languages come from the effective site configuration, not from guide counts.
    # Route/integration observations are supplied by the build adapter after rendering.
    $files=@(foreach($relative in $Policy.wrapper.requiredFiles) {
        $path=Resolve-GuideWorkspacePath $WorkspaceRoot $relative
        [pscustomobject]@{Path=$relative;State=if([IO.File]::Exists($path)){'present'}else{'missing'};Fix="Restore the required wrapper file: $relative"}
    })
    $translations=@(foreach($language in ($Languages | Select-Object -Unique)) {
        if ($language -notmatch '^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$') { throw "Invalid wrapper language: $language" }
        $relative="$($Policy.wrapper.sourcePath)/i18n/$language"
        $candidates=@(foreach($extension in @('yaml','yml')) {
            $path=Resolve-GuideWorkspacePath $WorkspaceRoot "$relative.$extension"
            if ([IO.File]::Exists($path)) { $path }
        })
        $keys=@();$catalogState='missing';$detail=$null
        if ($candidates.Count -gt 1) { $catalogState='ambiguous';$detail='Both YAML extensions exist; select one authoritative catalogue.' }
        elseif ($candidates.Count -eq 1) {
            try {
                Import-Module powershell-yaml -MinimumVersion 0.4.12 -ErrorAction Stop
                $catalog=ConvertFrom-Yaml ([IO.File]::ReadAllText($candidates[0])) -ErrorAction Stop
                $entries=@{}
                if ($catalog -is [Collections.IDictionary]) {
                    foreach($key in $catalog.Keys) { $entries[$key]=$catalog[$key] }
                } elseif ($catalog -is [Collections.IList]) {
                    foreach($entry in $catalog) {
                        if ($entry -isnot [Collections.IDictionary] -or -not $entry.Contains('id')) { throw 'Expected i18n records with an id.' }
                        if ($entries.ContainsKey($entry.id)) { throw "Duplicate i18n key: $($entry.id)" }
                        $entries[$entry.id]=$entry
                    }
                } else { throw 'Expected a YAML catalogue mapping or sequence.' }
                $catalogState='present'
                $keys=@(foreach($key in $Policy.wrapper.requiredI18nKeys) {
                    $state='missing'
                    if ($entries.ContainsKey($key)) {
                        $value=$entries[$key]
                        $values=if($value -is [Collections.IDictionary]) { @($value.Keys | Where-Object { $_ -in @('translation','zero','one','two','few','many','other') } | ForEach-Object { $value[$_] }) }else{@($value)}
                        $state=if(@($values | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) }).Count){'present'}else{'empty'}
                    }
                    [pscustomobject]@{Key=$key;State=$state;Fix="Supply a reviewed $language translation for '$key'."}
                })
            } catch { $catalogState='invalid';$detail=$_.Exception.Message }
        }
        $localCatalogue=$catalogState
        $scope='local-wrapper-yaml'
        if($PSBoundParameters.ContainsKey('EffectiveTranslations')){
            $effective=@($EffectiveTranslations|Where-Object Language -CEQ $language)
            if($effective.Count -ne 1 -or $effective[0].Scope -ne 'hugo-effective-i18n'){throw "Missing or ambiguous effective catalogue evidence for $language."}
            $keys=@(foreach($key in $Policy.wrapper.requiredI18nKeys){
                $entry=@($effective[0].Keys|Where-Object Key -CEQ $key)
                if($entry.Count -ne 1){throw "Missing or ambiguous effective translation evidence for $language/$key."}
                $present=$entry[0].State -in @('available','fallback') -and -not [string]::IsNullOrWhiteSpace($entry[0].Value)
                [pscustomobject]@{Key=$key;State=if($present){'present'}else{'missing'};Resolution=$entry[0].State;Fix="Supply a reviewed translation or intended fallback for '$key'."}
            })
            if($catalogState -in @('present','missing')){$catalogState='present'}
            $scope='hugo-effective-i18n'
        }
        [pscustomobject]@{Language=$language;Catalogue=$catalogState;LocalCatalogue=$localCatalogue;Detail=$detail;Keys=$keys;RequiredKeys=@($Policy.wrapper.requiredI18nKeys);Scope=$scope}
    })
    $routes=@(foreach($route in $Policy.wrapper.requiredRoutes) {
        [pscustomobject]@{Route=$route;State=if(-not $PSBoundParameters.ContainsKey('ObservedRoutes')){'unknown'}elseif($route -cin $ObservedRoutes){'present'}else{'missing'}}
    })
    $integration=@(foreach($point in $Policy.wrapper.integrationPoints) {
        [pscustomobject]@{Id=$point;State=if(-not $PSBoundParameters.ContainsKey('ObservedIntegrationPoints')){'unknown'}elseif($point -cin $ObservedIntegrationPoints){'present'}else{'missing'}}
    })
    [pscustomobject]@{SiteId=$Policy.siteId;Files=$files;Languages=$translations;Routes=$routes;IntegrationPoints=$integration;TranslationQualityAssessed=$false}
}