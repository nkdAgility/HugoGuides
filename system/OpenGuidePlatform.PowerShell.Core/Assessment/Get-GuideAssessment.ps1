function Get-GuideAssessment {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][Collections.IDictionary]$Policy,[Parameter(Mandatory)][string[]]$Languages,[Parameter(Mandatory)][Collections.IDictionary]$EffectiveProduction,[Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,[Parameter(Mandatory)][string]$PlatformVersion,[ValidateSet('local','canary','preview','production')][string]$Target='local',[object[]]$EffectiveTranslations)
    $findings=[Collections.Generic.List[object]]::new()
    function Add-Finding($code,$scope,$subject,$message,$fix,$severity='blocker') {
        $findings.Add([ordered]@{code=$code;severity=$severity;scope=$scope;subject=$subject;message=$message;remediation=$fix;evidence=@()})
    }
    foreach($finding in @(Get-GuidePolicyFinding $Policy)) { Add-Finding $finding.Code platform $finding.Subject 'The declared policy relationship is inconsistent.' 'Correct the reported policy relationship in the reviewed site policy.' }
    foreach($finding in @(Test-GuidePublicationPolicy $Policy $EffectiveProduction)) { Add-Finding $finding.Code platform $finding.Subject $finding.Reason 'Keep permanently excluded subjects disabled in effective production configuration and provide exclusion evidence.' $finding.Severity }
    foreach($environment in @($Policy.publication.environments | Where-Object name -EQ $Target)) {
        foreach($language in $environment.excludedLanguages) {
            if($language -in $Languages) {
                Add-Finding ENVIRONMENT_LANGUAGE_ENABLED language $language "The language is enabled in effective $Target configuration but excluded by publication policy." "Disable this language in the $Target configuration or review the environment exclusion policy."
            }
        }
    }
    $wrapperState='unknown'
    try {
        $wrapperArguments=@{}
        if($PSBoundParameters.ContainsKey('EffectiveTranslations')){$wrapperArguments.EffectiveTranslations=$EffectiveTranslations}
        $wrapper=Get-GuideWrapperStatus $WorkspaceRoot $Policy $Languages @wrapperArguments
        foreach($file in $wrapper.Files) { if($file.State -ne 'present'){Add-Finding WRAPPER_FILE_MISSING wrapper $file.Path 'A required wrapper file is missing.' $file.Fix;$wrapperState='incomplete'} }
        foreach($language in $wrapper.Languages) {
            if ($language.RequiredKeys.Count -gt 0 -and $language.Catalogue -ne 'present') { Add-Finding WRAPPER_CATALOGUE_UNAVAILABLE wrapper $language.Language "Local wrapper catalogue is $($language.Catalogue). $($language.Detail)" 'Restore or reconcile the local YAML catalogue, or supply effective module fallback evidence through the build adapter.';$wrapperState='incomplete' }
            foreach($key in $language.Keys) { if($key.State -ne 'present'){Add-Finding WRAPPER_TRANSLATION_MISSING wrapper "$($language.Language)/$($key.Key)" "Required translation is $($key.State)." $key.Fix;$wrapperState='incomplete'} }
            if($language.Scope -eq 'hugo-effective-i18n'){
                foreach($key in $language.Keys|Where-Object Resolution -EQ fallback){
                    Add-Finding WRAPPER_TRANSLATION_FALLBACK wrapper "$($language.Language)/$($key.Key)" 'Hugo resolved this key using fallback text.' 'Review the intended fallback; available text does not establish translation quality.' warning
                }
                if($language.LocalCatalogue -eq 'missing'){
                    Add-Finding WRAPPER_CATALOGUE_RESOLVED wrapper $language.Language 'Hugo supplied effective translation evidence without a local wrapper YAML catalogue.' 'Review the mounted catalogues and language quality; resolution alone does not establish a complete translation.' info
                }
            }
        }
        if(@($wrapper.Routes).Count -or @($wrapper.IntegrationPoints).Count) { Add-Finding WRAPPER_BUILD_EVIDENCE_PENDING wrapper $Policy.siteId 'Runtime routes and integration points have not been validated during Prepare.' 'Run Build and Validate to inspect the generated artifact.' info }
    } catch { Add-Finding WRAPPER_ASSESSMENT_FAILED wrapper $Policy.siteId $_.Exception.Message 'Correct the wrapper input and rerun Prepare.' }
    $guides=@(foreach($guide in $Policy.guides) {
        $editions=@(foreach($edition in $guide.editions) {
            $translations=@()
            try {
                # Observe each edition independently so a malformed document does not hide other findings.
                $subset=$Policy.Clone();$guideSubset=$guide.Clone();$guideSubset.editions=@($edition);$subset.guides=@($guideSubset)
                $observed=(Get-GuideInventory $WorkspaceRoot $subset).Guides[0].Editions[0]
                $translations=@(foreach($translation in $observed.Translations) {
                    $subject="$($guide.id)/$($edition.id)/$($translation.Language)"
                    if($translation.FindingCode){Add-Finding $translation.FindingCode translation $subject "Declared $($translation.Intent) content is not ready (body: $($translation.Body))." 'Restore the required body/resource or review the declared publication intent; preserve intentional PDF-only and fallback states.'}
                    if($translation.DeprecatedLang){Add-Finding DEPRECATED_LANG translation $subject 'The document contains deprecated lang front matter.' 'Remove lang from Hugo front matter; pass the filename/default language through Pandoc metadata.'}
                    foreach($download in $translation.Downloads){if(-not $download.Exists){Add-Finding DOWNLOAD_MISSING download "$subject/$($download.Path)" 'A declared download is missing.' 'Restore supplied/protected downloads; generate only resources declared generated.' $(if($download.Handling -eq 'generated'){'warning'}else{'blocker'})}}
                    [ordered]@{language=$translation.Language;state=$translation.State;body=$translation.Body;downloads=@($translation.Downloads|ForEach-Object {[ordered]@{path=$_.Path;handling=$_.Handling}})}
                })
            } catch { Add-Finding EDITION_ASSESSMENT_FAILED edition "$($guide.id)/$($edition.id)" $_.Exception.Message 'Correct the edition input and rerun Prepare; other editions are assessed independently.' }
            [ordered]@{id=$edition.id;translations=$translations}
        })
        [ordered]@{id=$guide.id;editions=$editions}
    })
    $policyJson=$Policy|ConvertTo-Json -Depth 100 -Compress
    [ordered]@{schemaVersion=1;sourceCommit=$SourceCommit;platformVersion=$PlatformVersion;policyDigest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($policyJson))).ToLowerInvariant();target=$Target;stage='Prepare';outcome=if(@($findings|Where-Object severity -eq blocker).Count){'fail'}else{'pass'};findings=@($findings.ToArray());inventory=[ordered]@{wrapper=[ordered]@{state=$wrapperState;languages=@($Languages)};guides=$guides}}
}