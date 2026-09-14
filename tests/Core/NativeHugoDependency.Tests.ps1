BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module "$root/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/NativeHugoDependency.psm1" -Force
}
Describe 'Coordinated native Hugo dependency plan' {
    BeforeEach {
        $workspace=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory("$workspace/site")|Out-Null
        $legacy='github.com/nkdAgility/HugoGuides/module'
        $canonical='github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides'
        [IO.File]::WriteAllText("$workspace/site/go.mod","module example.invalid/wrapper`n`nrequire $legacy v0.6.8`n")
        [IO.File]::WriteAllText("$workspace/site/go.sum","$legacy v0.6.8 h1:old`nexample.invalid/other v1.0.0 h1:keep`n")
        [IO.File]::WriteAllText("$workspace/site/hugo.yaml","# Keep wrapper formatting`nmodule:`n  imports:`n    - path: $legacy # renderer`ntitle: Bespoke wrapper`n")
        [IO.File]::WriteAllText("$workspace/site/hugo.local.yaml","module:`n  replacements:`n    - $legacy -> ../../HugoGuides/module`n")
        $native=@{path=$canonical;version='v1.2.3-Preview.1';sourceCommit=('a'*40)}
        $parameters=@{WorkspaceRoot=$workspace;SourcePath='site';NativeModule=$native}
        Mock Invoke-NativeGo -ModuleName NativeHugoDependency {
            param($Arguments,$Stage)
            if($Arguments[1] -eq 'edit' -and $Arguments[2] -eq '-json') {
                $text=[IO.File]::ReadAllText("$Stage/go.mod")
                if($text -notmatch 'require\s+(\S+)\s+(\S+)'){throw 'Fixture requires a native/legacy dependency.'}
                return (@{Require=@(@{Path=$Matches[1];Version=$Matches[2]})}|ConvertTo-Json -Depth 4)
            }
            if($Arguments[1] -eq 'edit') {
                $require=@($Arguments|Where-Object {$_ -like '-require=*'})[0].Substring(9).Replace('@',' ')
                [IO.File]::WriteAllText("$Stage/go.mod","module example.invalid/wrapper`nrequire $require`n")
                return ''
            }
            $parts=$Arguments[3].Split('@')
            [IO.File]::AppendAllText("$Stage/go.sum","$($parts[0]) $($parts[1]) h1:new`n")
            return (@{Path=$parts[0];Version=$parts[1];Origin=@{Hash=('a'*40)};Sum='h1:new';GoModSum='h1:mod'}|ConvertTo-Json)
        }
    }
    It 'plans dependency and YAML identity changes while preserving all tracked input bytes' {
        $before=(Get-FileHash "$workspace/site/hugo.yaml").Hash
        $plan=New-GuideNativeHugoUpdatePlan @parameters
        (Get-FileHash "$workspace/site/hugo.yaml").Hash | Should -Be $before
        [Text.Encoding]::UTF8.GetString($plan.Files['site/hugo.yaml']) | Should -Be "# Keep wrapper formatting`nmodule:`n  imports:`n    - path: $canonical # renderer`ntitle: Bespoke wrapper`n"
        [Text.Encoding]::UTF8.GetString($plan.Files['site/hugo.local.yaml']) | Should -Match ([regex]::Escape("$canonical -> ../../HugoGuides/module"))
        [Text.Encoding]::UTF8.GetString($plan.Files['site/go.sum']) | Should -Match 'example.invalid/other'
        [Text.Encoding]::UTF8.GetString($plan.Files['site/go.sum']) | Should -Not -Match ([regex]::Escape($legacy))
        $plan.ExpectedHashes['site/hugo.yaml'] | Should -Be $before.ToLowerInvariant()
    }
    It 'refuses a dependency version that differs from the installation record before download' {
        {New-GuideNativeHugoUpdatePlan @parameters -PreviousVersion v1.0.0} | Should -Throw '*differs from its installation record*'
        Should -Invoke Invoke-NativeGo -ModuleName NativeHugoDependency -Times 0 -Exactly -ParameterFilter {$Arguments[1] -eq 'download'}
    }
    It 'refuses a mismatched native source without altering consumer YAML' {
        $native.sourceCommit='b'*40
        {New-GuideNativeHugoUpdatePlan @parameters} | Should -Throw '*does not match*'
        Get-Content "$workspace/site/hugo.yaml" -Raw | Should -Match ([regex]::Escape($legacy))
    }
    It 'removes migration replacements outside local while retaining unrelated configuration' {
        Add-Content "$workspace/site/hugo.yaml" "  # wrapper-owned comment"
        [IO.File]::WriteAllText("$workspace/site/hugo.production.yaml","module:`n  replacements:`n    - $legacy -> ../temporary`nparams:`n  keep: true`n")
        $plan=New-GuideNativeHugoUpdatePlan @parameters
        [Text.Encoding]::UTF8.GetString($plan.Files['site/hugo.production.yaml']) | Should -Be "module:`nparams:`n  keep: true`n"
    }
    It 'refuses unsupported inline YAML instead of reserializing the wrapper' {
        [IO.File]::WriteAllText("$workspace/site/hugo.yaml","module: {imports: [{path: $legacy}]}")
        {New-GuideNativeHugoUpdatePlan @parameters} | Should -Throw '*Reconcile the module import format*'
    }
}
