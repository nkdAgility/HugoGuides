BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/WorkflowCallers.psm1" -Force
}
Describe 'Site-owned workflow reference planning' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory "$workspace/.github/workflows" -Force|Out-Null
        $path="$workspace/.github/workflows/main.yaml"
        $previous=@{releaseTag='v1.0.0';managedFiles=@{'.github/workflows/main.yaml'='legacy-hash'}}
    }
    It 'rejects flow callers even when script text resembles the expected block caller' {
        Set-Content $path @'
jobs:
  build: {uses: 'nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0'}
  notes:
    steps:
      - run: |
          uses: nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0
'@
        {New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous} | Should -Throw '*Ambiguous OGP caller syntax*'
    }
    It 'changes only semantic uses nodes and preserves BOM CRLF quotes comments and script text' {
        $content=@'
# owner: site
jobs:
  build:
    uses: "nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0" # retain
  notes:
    steps:
      - run: |
          uses: nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0
'@ -replace '\r?\n',"`r`n"
        [IO.File]::WriteAllText($path,$content,[Text.UTF8Encoding]::new($true))
        $plan=New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous
        $expected=$content.Replace('guide-site-build.yaml@v1.0.0"','guide-site-build.yaml@v1.0.1"')
        $bytes=[byte[]](@(239,187,191)+[Text.Encoding]::UTF8.GetBytes($expected))
        [Convert]::ToBase64String($plan.Files['.github/workflows/main.yaml'])|Should -BeExactly ([Convert]::ToBase64String($bytes))
    }
    It 'rejects noncanonical repository spelling rather than ignoring a second caller' {
        Set-Content $path @'
jobs:
  build:
    uses: nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0
  cleanup:
    uses: nkdagility/openguideplatform/.github/workflows/guide-site-close-pr.yaml@v1.0.0
'@
        {New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous}|Should -Throw '*Unsupported OGP caller reference*'
    }
    It 'rejects anchored caller scalars' {
        Set-Content $path @'
jobs:
  build:
    uses: &shared nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0
'@
        {New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous}|Should -Throw '*Ambiguous OGP caller syntax*'
    }
    It 'rejects escaped references in a newly added caller rather than skipping them' {
        Set-Content $path @'
jobs:
  build:
    uses: nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0
'@
        Set-Content "$workspace/.github/workflows/cleanup.yaml" @'
jobs:
  cleanup:
    uses: "nkdAgility\u002fOpenGuidePlatform/.github/workflows/guide-site-close-pr.yaml@v1.0.0"
'@
        {New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous}|Should -Throw '*Ambiguous OGP caller syntax*'
    }
    It 'refuses removal of a previously recorded caller' {
        Set-Content $path 'name: replacement'
        {New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous}|Should -Throw '*Missing or unrecognised OGP caller*'
    }
    It 'rejects linked workflows before reading or changing the target' {
        $outside=Join-Path $TestDrive 'external.yaml'
        Set-Content $outside 'name: external'
        New-Item -ItemType SymbolicLink -Path $path -Target $outside|Out-Null
        {New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous}|Should -Throw '*Linked workflow paths*'
    }
}

Describe 'Recorded references and inherited callers' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory "$workspace/.github/workflows" -Force|Out-Null
        $path="$workspace/.github/workflows/custom.yaml"
        $build='nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml'
        $cleanup='nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-close-pr.yaml'
    }
    It 'rejects a removed reference even when another recorded reference remains' {
        Set-Content $path "jobs:`n  build:`n    uses: ${build}@v1.0.0"
        $previous=@{releaseTag='v1.0.0';workflowCallers=@{'.github/workflows/custom.yaml'=@($build,$cleanup)}}
        {New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous}|Should -Throw '*Missing or unrecognised OGP caller reference*'
        Test-Path "$workspace/.github/workflows/main.yaml"|Should -BeFalse
    }
    It 'rejects replacement of a recorded build reference with cleanup' {
        Set-Content $path "jobs:`n  build:`n    uses: ${cleanup}@v1.0.0"
        $previous=@{releaseTag='v1.0.0';workflowCallers=@{'.github/workflows/custom.yaml'=@($build)}}
        {New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous}|Should -Throw '*Missing or unrecognised OGP caller reference*'
    }
    It 'allows new references while retaining every recorded reference' {
        Set-Content $path "jobs:`n  build:`n    uses: ${build}@v1.0.0`n  cleanup:`n    uses: ${cleanup}@v1.0.0"
        $previous=@{releaseTag='v1.0.0';workflowCallers=@{'.github/workflows/custom.yaml'=@($build)}}
        $plan=New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous
        $plan.Callers['.github/workflows/custom.yaml'].Count|Should -Be 2
    }
    It 'rejects inherited OGP calls on first install before creating a starter' -ForEach @(
        @{Yaml="shared: &call`n  uses: nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0`njobs:`n  build:`n    <<: *call"}
        @{Yaml="shared: &jobs`n  build:`n    uses: nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0`njobs:`n  <<: *jobs"}
        @{Yaml="shared: &root`n  jobs:`n    build:`n      uses: nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0`n<<: *root"}
        @{Yaml="shared: &call`n  uses: nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@v1.0.0`njobs:`n  build: *call"}
    ) {
        Set-Content $path $Yaml
        {New-GuideWorkflowCallerPlan $workspace v1.0.0 $null 'starter'}|Should -Throw '*Ambiguous OGP caller syntax*'
        Test-Path "$workspace/.github/workflows/main.yaml"|Should -BeFalse
    }
    It 'rejects an unrecorded inherited caller during update' {
        Set-Content $path "jobs:`n  build:`n    uses: ${build}@v1.0.0"
        Set-Content "$workspace/.github/workflows/cleanup.yaml" "shared: &call`n  uses: ${cleanup}@v1.0.0`njobs:`n  cleanup:`n    <<: [*call]"
        $previous=@{releaseTag='v1.0.0';workflowCallers=@{'.github/workflows/custom.yaml'=@($build)}}
        {New-GuideWorkflowCallerPlan $workspace v1.0.1 $previous}|Should -Throw '*Ambiguous OGP caller syntax*'
    }
    It 'preserves unrelated aliases merges and script text' {
        $yaml="env-values: &environment`n  uses: ${cleanup}@v1.0.0`nenv:`n  <<: *environment`nshared: &settings`n  timeout-minutes: 10`njobs:`n  build:`n    <<: *settings`n    uses: ${build}@v1.0.0`n  notes:`n    steps:`n      - run: |`n          uses: ${cleanup}@v1.0.0"
        Set-Content $path $yaml -NoNewline
        $plan=New-GuideWorkflowCallerPlan $workspace v1.0.0 $null
        [Text.Encoding]::UTF8.GetString($plan.Files['.github/workflows/custom.yaml'])|Should -BeExactly $yaml
    }
}