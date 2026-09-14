BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
    function Read-DownloadFiles($directory){@(Get-ChildItem $directory -File -Recurse|ForEach-Object {[pscustomobject]@{Path=[IO.Path]::GetRelativePath($directory,$_.FullName).Replace('\','/');Sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})}
}
Describe 'Declared download publication' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $policy=Get-Content "$root/tests/Contracts/fixtures/single-guide.site-policy.json" -Raw|ConvertFrom-Json -AsHashtable
        $edition=$policy.guides[0].editions[0]
        $source="$workspace/$($policy.guides[0].contentRoot)/$($edition.path)"
        $artifact="$workspace/artifact"
        [IO.Directory]::CreateDirectory($source)|Out-Null
        [IO.Directory]::CreateDirectory("$artifact/downloads")|Out-Null
        $edition.translations=@(@{language='en';intent='pdf-only';downloads=@(@{path='approved.pdf';handling='protected';publishedPaths=@('downloads/approved.pdf')})})
        [IO.File]::WriteAllText("$source/approved.pdf",'%PDF- approved bytes')
        $argsForDownloads=@{WorkspaceRoot=$workspace;Policy=$policy;Target='production';EnabledLanguages=@('en')}
    }
    It 'maps edition-relative source to declared public paths and preserves a PDF-only edition' {
        Copy-Item "$source/approved.pdf" "$artifact/downloads/approved.pdf"
        $requirements=Get-GuideDownloadRequirements @argsForDownloads
        $requirements.RequiredPaths | Should -Contain 'downloads/approved.pdf'
        (Test-GuideDownloadPublication $requirements (Read-DownloadFiles $artifact)).Outcome | Should -Be pass
    }
    It 'matches regional language casing without weakening exclusion policy' {
        $edition.translations[0].language='es-ES'
        $edition.translations[0].intent='web'
        $argsForDownloads.EnabledLanguages=@('es-es')
        @( (Get-GuideDownloadRequirements @argsForDownloads).Required ).Count | Should -Be 1
        $policy.publication.permanentExclusions=@(@{environment='production';subject='language';id='ES-es';reason='Excluded'})
        @( (Get-GuideDownloadRequirements @argsForDownloads).Forbidden ).Count | Should -Be 1
    }
    It 'fails missing declared downloads and altered supplied PDF bytes' {
        $requirements=Get-GuideDownloadRequirements @argsForDownloads
        (Test-GuideDownloadPublication $requirements @()).Findings.Code | Should -Contain REQUIRED_DOWNLOAD_MISSING
        [IO.File]::WriteAllText("$artifact/downloads/approved.pdf",'%PDF- different bytes')
        (Test-GuideDownloadPublication $requirements (Read-DownloadFiles $artifact)).Findings.Code | Should -Contain DOWNLOAD_BYTES_CHANGED
    }
    It 'reports an absent public mapping rather than guessing a Hugo URL from source folders' {
        $edition.translations[0].downloads[0].Remove('publishedPaths')|Out-Null
        (Get-GuideDownloadRequirements @argsForDownloads).Findings.Code | Should -Contain DOWNLOAD_PUBLICATION_PATH_UNDECLARED
    }
    It 'defers inferred PDF destinations until the actual artifact exists and rejects absent bytes' {
        $policy.wrapper.discovery='source'
        $edition.translations[0].downloads[0].publicationRoots=@('/downloads/')
        $edition.translations[0].downloads[0].Remove('publishedPaths')|Out-Null
        @( (Get-GuideDownloadRequirements @argsForDownloads).Findings ).Count|Should -Be 0
        (Get-GuideDownloadRequirements @argsForDownloads -ArtifactFiles @()).Findings.Code|Should -Contain DOWNLOAD_PUBLICATION_PATH_UNDECLARED
        Copy-Item "$source/approved.pdf" "$artifact/downloads/approved.pdf"
        $requirements=Get-GuideDownloadRequirements @argsForDownloads -ArtifactFiles @(Read-DownloadFiles $artifact)
        $requirements.RequiredPaths|Should -Contain 'downloads/approved.pdf'
        (Test-GuideDownloadPublication $requirements (Read-DownloadFiles $artifact)).Outcome|Should -Be pass
    }
    It 'does not authorize arbitrary extra copies of shared excluded bytes when inferring paths' {
        $policy.wrapper.discovery='source'
        $edition.translations[0].downloads[0].Remove('publishedPaths')|Out-Null
        $edition.translations[0].downloads[0].publicationRoots=@('/downloads/')
        $edition.translations+=@{language='min';intent='excluded';downloads=@(@{path='fallback.pdf';handling='supplied';publicationRoots=@('/min/')})}
        Copy-Item "$source/approved.pdf" "$source/fallback.pdf"
        Copy-Item "$source/approved.pdf" "$artifact/downloads/approved.pdf"
        Copy-Item "$source/approved.pdf" "$artifact/downloads/extra.pdf"
        $requirements=Get-GuideDownloadRequirements @argsForDownloads -ArtifactFiles @(Read-DownloadFiles $artifact)
        $requirements.RequiredPaths|Should -Not -Contain 'downloads/extra.pdf'
        (Test-GuideDownloadPublication $requirements (Read-DownloadFiles $artifact)).Findings.Code|Should -Contain FORBIDDEN_DOWNLOAD_PRESENT
    }
    It 'accepts an owner-qualified custom PDF URL from the built translation catalogue' {
        $policy.wrapper.discovery='source'
        $edition.translations[0].downloads[0].Remove('publishedPaths')|Out-Null
        Copy-Item "$source/approved.pdf" "$artifact/downloads/renamed.pdf"
        $mapping=@{VersionPath="$($policy.guides[0].id)/$($edition.path)";Language='en';Path='downloads/renamed.pdf'}
        $requirements=Get-GuideDownloadRequirements @argsForDownloads -ArtifactFiles @(Read-DownloadFiles $artifact) -PublishedDownloads @($mapping)
        $requirements.RequiredPaths|Should -Contain 'downloads/renamed.pdf'
        $mapping.Language='min'
        (Get-GuideDownloadRequirements @argsForDownloads -ArtifactFiles @(Read-DownloadFiles $artifact) -PublishedDownloads @($mapping)).Findings.Code|Should -Contain DOWNLOAD_PUBLICATION_PATH_UNDECLARED
    }
    It 'rejects prohibited PDFs copied outside language directories, including renamed copies' {
        $policy.publication.permanentExclusions=@(@{environment='production';subject='language';id='min';reason='Never production'})
        $edition.translations+=@{language='min';intent='web';downloads=@(@{path='guide.min.pdf';handling='supplied';publishedPaths=@('min/guide.min.pdf')})}
        [IO.File]::WriteAllText("$source/guide.min.pdf",'%PDF- prohibited bytes')
        Copy-Item "$source/approved.pdf" "$artifact/downloads/approved.pdf"
        Copy-Item "$source/guide.min.pdf" "$artifact/downloads/renamed.pdf"
        $requirements=Get-GuideDownloadRequirements @argsForDownloads
        $result=Test-GuideDownloadPublication $requirements (Read-DownloadFiles $artifact)
        $result.Findings.Code | Should -Contain FORBIDDEN_DOWNLOAD_PRESENT
        $result.Findings.Path | Should -Contain 'downloads/renamed.pdf'
    }
    It 'preserves an explicitly allowed shared fallback PDF without allowing extra excluded copies' {
        $edition.translations+=@{language='min';intent='excluded';downloads=@(@{path='fallback.pdf';handling='supplied';publishedPaths=@('min/fallback.pdf')})}
        Copy-Item "$source/approved.pdf" "$source/fallback.pdf"
        Copy-Item "$source/approved.pdf" "$artifact/downloads/approved.pdf"
        $requirements=Get-GuideDownloadRequirements @argsForDownloads
        (Test-GuideDownloadPublication $requirements (Read-DownloadFiles $artifact)).Outcome | Should -Be pass
        Copy-Item "$source/fallback.pdf" "$artifact/downloads/extra.pdf"
        (Test-GuideDownloadPublication $requirements (Read-DownloadFiles $artifact)).Findings.Code | Should -Contain FORBIDDEN_DOWNLOAD_PRESENT
    }
    It 'requires fallback downloads without requiring the fallback translation to have a web body' {
        $edition.translations[0].intent='fallback';$edition.translations[0].fallbackLanguage='fa'
        Copy-Item "$source/approved.pdf" "$artifact/downloads/approved.pdf"
        (Test-GuideDownloadPublication (Get-GuideDownloadRequirements @argsForDownloads) (Read-DownloadFiles $artifact)).Outcome | Should -Be pass
    }
    It 'validates public download paths before using them as artifact expectations' {
        $edition.translations[0].downloads[0].publishedPaths=@('../escape.pdf')
        { Get-GuideDownloadRequirements @argsForDownloads } | Should -Throw '*Unsafe published*'
    }
    It 'feeds missing declared downloads into the normal artifact assessment' {
        [IO.File]::WriteAllText("$artifact/index.html",'Guide')
        [IO.File]::WriteAllText("$workspace/hugo.log",'Build complete')
        $identity=New-GuideArtifactIdentity $artifact production ('a'*40) '0.0.0'
        $identity|ConvertTo-Json -Depth 30|Set-Content "$workspace/identity.json"
        $requirements=Get-GuideDownloadRequirements @argsForDownloads
        $result=Get-GuideArtifactAssessment -ArtifactRoot $artifact -IdentityPath "$workspace/identity.json" -HugoLogPath "$workspace/hugo.log" -SourceCommit ('a'*40) -Target production -RequiredDownloads $requirements.RequiredPaths -DownloadRequirements $requirements
        $result.Outcome | Should -Be fail
        $result.Findings.Code | Should -Contain REQUIRED_DOWNLOAD_MISSING
    }
}