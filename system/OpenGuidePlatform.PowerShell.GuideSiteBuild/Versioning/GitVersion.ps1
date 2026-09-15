# Shared by platform and guide-site builds. GitVersion remains independent of CI providers.
function ConvertTo-GuideGitVersion6Configuration {
    param([Parameter(Mandatory)][string]$Text)
    Import-Module powershell-yaml -MinimumVersion 0.4.12
    $configuration=ConvertFrom-Yaml $Text -Ordered
    $branches=if($configuration.Contains('branches')){$configuration.branches}else{[ordered]@{}}
    $legacy=$configuration.Contains('continuous-delivery-fallback-tag')
    foreach($branch in $branches.Values){
        foreach($key in @('tag','is-mainline','prevent-increment-of-merged-branch-version')){
            if($branch.Contains($key)){$legacy=$true}
        }
    }
    if(-not $legacy){return $Text}
    # GitVersion 6 renamed modes as well as configuration keys. Main builds must
    # advance their prerelease counter, including ordinary commits without directives.
    $nodes=@($configuration)+@($branches.Values)
    foreach($node in $nodes){
        if($node.Contains('mode')){
            $node.mode=switch($node.mode){'ContinuousDeployment'{'ContinuousDelivery'} 'ContinuousDelivery'{'ManualDeployment'} default{$node.mode}}
        }
        foreach($pair in @(@('tag','label'),@('is-mainline','is-main-branch'))){
            if($node.Contains($pair[0])){
                if($node.Contains($pair[1])){throw "GitVersion configuration contains both $($pair[0]) and $($pair[1]). Keep the GitVersion 6 setting and rerun Update."}
                $node[$pair[1]]=$node[$pair[0]];$node.Remove($pair[0])
            }
        }
        if($node.Contains('prevent-increment-of-merged-branch-version')){
            if(-not $node.Contains('prevent-increment')){$node['prevent-increment']=[ordered]@{}}
            if($node['prevent-increment'].Contains('of-merged-branch')){throw 'GitVersion contains conflicting merged-branch increment settings. Keep prevent-increment.of-merged-branch and rerun Update.'}
            $node['prevent-increment']['of-merged-branch']=$node['prevent-increment-of-merged-branch-version']
            $node.Remove('prevent-increment-of-merged-branch-version')
        }
    }
    # v6 source-branches refer to configuration names, not Git branch aliases.
    # The existing main configuration covers both master and main.
    if($branches.Contains('main') -and -not $branches.Contains('master') -and $branches.main.Contains('regex') -and $branches.main.regex -and 'master' -match $branches.main.regex){
        foreach($node in $branches.Values){
            if($node.Contains('source-branches')){
                $node['source-branches']=@($node['source-branches']|ForEach-Object {if($_ -eq 'master'){'main'}else{$_}}|Select-Object -Unique)
            }
        }
    }
    $configuration.Remove('continuous-delivery-fallback-tag')
    # Commit message increments are enabled by default; preserve an explicit site override.
    if(-not $configuration.Contains('commit-message-incrementing')){$configuration['commit-message-incrementing']='Enabled'}
    return ($configuration|ConvertTo-Yaml)
}
function Get-GuideGitVersionConfigurationPath {
    param([Parameter(Mandatory)][string]$WorkspaceRoot)
    $path=Join-Path $WorkspaceRoot '.github/GitVersion.yml'
    $original=[IO.File]::ReadAllText($path)
    $converted=ConvertTo-GuideGitVersion6Configuration -Text $original
    if($converted -ceq $original){return $path}
    $directory=Join-Path $WorkspaceRoot '.processing/tools/gitversion/config'
    [IO.Directory]::CreateDirectory($directory)|Out-Null
    # Each invocation owns its file; concurrent readers never share a rewritten path.
    $generated=Join-Path $directory (([guid]::NewGuid().ToString("N"))+".yml")
    [IO.File]::WriteAllText($generated,$converted,[Text.UTF8Encoding]::new($false))
    Write-Verbose 'Using GitVersion 6 compatibility configuration. Update migrates the site-owned configuration; Prepare does not edit it.'
    return $generated
}
function Install-GuideGitVersion {
    param([Parameter(Mandatory)][string]$WorkspaceRoot)
    $tools=Join-Path $WorkspaceRoot '.processing/tools/gitversion'
    # update also installs a missing tool and upgrades an existing v5 cache.
    & dotnet tool update GitVersion.Tool --version '6.*' --tool-path $tools
    if($LASTEXITCODE -ne 0){throw 'GitVersion 6 installation failed. Install the .NET SDK, restore NuGet connectivity and rerun ./build.ps1 Dependencies.'}
}
function Add-GuideGitVersionMessageDefaults {
    param([Parameter(Mandatory)][string]$Text)
    Import-Module powershell-yaml -MinimumVersion 0.4.12
    $configuration=ConvertFrom-Yaml $Text -Ordered
    $defaults=[ordered]@{
        'commit-message-incrementing'='Enabled'
        'major-version-bump-message'='(\+semver:\s?(breaking|major))|(^[a-z]+(\([^\r\n)]+\))?!:)|(BREAKING[ -]CHANGE:)'
        'minor-version-bump-message'='(\+semver:\s?(feature|minor))|(^feat(\([^\r\n)]+\))?:)'
        'patch-version-bump-message'='(\+semver:\s?(fix|patch))|(^(fix|perf)(\([^\r\n)]+\))?:)'
        'no-bump-message'='\+semver:\s?(none|skip)'
    }
    $changed=$false
    foreach($key in $defaults.Keys){
        if(-not $configuration.Contains($key)){$configuration[$key]=$defaults[$key];$changed=$true}
    }
    if(-not $changed){return $Text}
    return ($configuration|ConvertTo-Yaml)
}
