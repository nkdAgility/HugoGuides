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
