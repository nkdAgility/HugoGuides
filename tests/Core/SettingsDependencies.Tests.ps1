BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $resolver="$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1"
}
Describe 'Settings YAML dependency compatibility' {
    It 'installs a compatible module when available version is <available>' -ForEach @(
        @{available='0.4.11';installs=1},@{available='0.4.12';installs=0}
    ) {
        New-Item -ItemType Directory "$TestDrive/.OpenGuidePlatform" -Force|Out-Null
        "platform:`n  version: v1`n  ring: production`nsite:`n  source: site`ndelivery: {}"|Set-Content "$TestDrive/.OpenGuidePlatform/settings.yaml"
        Mock Get-Module { [pscustomobject]@{Version=[version]$available} } -ParameterFilter {$ListAvailable -and $Name -contains 'powershell-yaml'}
        Mock Install-Module {} -ParameterFilter {$Name -eq 'powershell-yaml'}
        $settings=& $resolver -WorkspaceRoot $TestDrive -ReadSettings
        $settings.platform.version|Should -Be v1
        Should -Invoke Install-Module -Times $installs -Exactly -ParameterFilter {$Name -eq 'powershell-yaml' -and $MinimumVersion -eq '0.4.12'}
    }
}
