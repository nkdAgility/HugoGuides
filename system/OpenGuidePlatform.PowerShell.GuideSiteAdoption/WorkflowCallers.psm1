#Requires -Version 7.4
function New-GuideWorkflowCallerPlan {
    [CmdletBinding()]
    param([string]$WorkspaceRoot,[string]$ReleaseTag,$Previous,[string]$Starter)
    Import-Module powershell-yaml -MinimumVersion 0.4.12 -ErrorAction Stop
    $files=[ordered]@{}; $expected=[ordered]@{}; $callers=[ordered]@{}
    $directory=Join-Path $WorkspaceRoot '.github/workflows'
    if(Test-Path $directory){
        $cursor=Get-Item $directory -Force
        while($cursor){
            if($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked workflow paths are not supported.'}
            $cursor=$cursor.Parent
        }
        foreach($item in Get-ChildItem $directory -File | Where-Object Extension -In '.yaml','.yml'){
            if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked workflow paths are not supported.'}
            $original=[IO.File]::ReadAllBytes($item.FullName)
            $bom=$original.Length -ge 3 -and $original[0] -eq 239 -and $original[1] -eq 187 -and $original[2] -eq 191
            $offset=if($bom){3}else{0}
            $text=[Text.UTF8Encoding]::new($false,$true).GetString($original,$offset,$original.Length-$offset)
            $stream=[YamlDotNet.RepresentationModel.YamlStream]::new()
            $stream.Load([IO.StringReader]::new($text))
            if($stream.Documents.Count -ne 1){throw "Expected one workflow document in $($item.Name)."}
            $yaml=$stream.Documents[0].RootNode
            # Inspect merge sources before discovery: YamlStream resolves aliases,
            # but does not expose inherited uses entries as direct job children.
            $pending=[Collections.Generic.Queue[object]]::new()
            $pending.Enqueue(@{Node=$yaml;Merged=$false;Context='root'})
            $directSeen=[Collections.Generic.HashSet[object]]::new([Collections.Generic.ReferenceEqualityComparer]::Instance)
            $mergedSeen=[Collections.Generic.HashSet[object]]::new([Collections.Generic.ReferenceEqualityComparer]::Instance)
            while($pending.Count){
                $entry=$pending.Dequeue();$node=$entry.Node
                $seen=$directSeen; if($entry.Merged){$seen=$mergedSeen}
                if(-not $seen.Add($node)){continue}
                if($node -is [YamlDotNet.RepresentationModel.YamlMappingNode]){
                    foreach($pair in $node.Children.GetEnumerator()){
                        if($entry.Context -eq 'job' -and $entry.Merged -and $pair.Key.Value -eq 'uses' -and
                            $pair.Value -is [YamlDotNet.RepresentationModel.YamlScalarNode] -and
                            $pair.Value.Value.StartsWith('nkdAgility/OpenGuidePlatform/',[StringComparison]::OrdinalIgnoreCase)){
                            throw "Ambiguous OGP caller syntax in $($item.Name). Use literal block-style job uses entries instead of YAML merges or aliases."
                        }
                        if($pair.Key.Value -eq '<<'){
                            $pending.Enqueue(@{Node=$pair.Value;Merged=$true;Context=$entry.Context})
                        }elseif($entry.Context -eq 'root' -and $pair.Key.Value -eq 'jobs'){
                            $pending.Enqueue(@{Node=$pair.Value;Merged=$entry.Merged;Context='jobs'})
                        }elseif($entry.Context -eq 'jobs'){
                            $pending.Enqueue(@{Node=$pair.Value;Merged=$entry.Merged;Context='job'})
                        }
                    }
                }elseif($node -is [YamlDotNet.RepresentationModel.YamlSequenceNode]){
                    foreach($child in $node.Children){$pending.Enqueue(@{Node=$child;Merged=$entry.Merged;Context=$entry.Context})}
                }
            }
            $references=@();$spans=@()
            $jobs=$null
            if($yaml -is [YamlDotNet.RepresentationModel.YamlMappingNode]){$jobs=$yaml.Children[[YamlDotNet.RepresentationModel.YamlScalarNode]::new('jobs')]}
            if($jobs -is [YamlDotNet.RepresentationModel.YamlMappingNode]){
                foreach($job in $jobs.Children.Values){
                    $uses=$null
                    if($job -is [YamlDotNet.RepresentationModel.YamlMappingNode]){$uses=$job.Children[[YamlDotNet.RepresentationModel.YamlScalarNode]::new('uses')]}
                    if($uses -is [YamlDotNet.RepresentationModel.YamlScalarNode] -and $uses.Value.StartsWith('nkdAgility/OpenGuidePlatform/',[StringComparison]::OrdinalIgnoreCase)){
                        $reference=$uses.Value
                        if($reference -cnotmatch '^nkdAgility/OpenGuidePlatform/\.github/workflows/guide-site-(build|close-pr)\.yaml@(?<version>v[0-9]+(?:\.[0-9]+){0,2}(?:-[A-Za-z0-9.-]+)?)$'){
                            throw "Unsupported OGP caller reference in $($item.Name): $reference. Reconcile the caller manually."
                        }
                        $allowed=if($Previous){if($Previous.ContainsKey('workflowReference')){[string]$Previous.workflowReference}else{[string]$Previous.releaseTag}}else{$ReleaseTag}
                        if($Matches.version -cne $allowed){throw "Conflicting OGP caller version in $($item.Name): expected $allowed. Reconcile the caller manually."}
                        $spanStart=[int]$uses.Start.Index;$spanLength=[int]($uses.End.Index-$uses.Start.Index)
                        $literal=$text.Substring($spanStart,$spanLength)
                        if($job.Style -eq 'Flow' -or -not $uses.Anchor.IsEmpty -or -not $job.Anchor.IsEmpty -or -not $jobs.Anchor.IsEmpty -or
                            $literal -cnotin @($reference,('"'+$reference+'"'),("'"+$reference+"'"))){
                            throw "Ambiguous OGP caller syntax in $($item.Name). Use literal block-style job uses entries."
                        }
                        $quote=if($literal -ceq $reference){''}else{$literal.Substring(0,1)}
                        $spans+=@{Index=$spanStart;Length=$spanLength;Replacement=$quote+$reference.Substring(0,$reference.LastIndexOf('@')+1)+$ReleaseTag+$quote}
                        $references+= $reference
                    }
                }
            }
            if(-not $references.Count){continue}
            # Source spans come from job-level YAML nodes, never matching text in scripts.
            $relative='.github/workflows/'+$item.Name
            $expected[$relative]=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($original)).ToLowerInvariant()
            foreach($span in $spans|Sort-Object Index -Descending){
                $text=$text.Remove($span.Index,$span.Length).Insert($span.Index,$span.Replacement)
            }
            $bytes=[Text.Encoding]::UTF8.GetBytes($text)
            if($bom){$bytes=[byte[]](@(239,187,191)+$bytes)}
            $files[$relative]=$bytes
            $callers[$relative]=@($references|ForEach-Object {$_.Substring(0,$_.LastIndexOf('@'))}|Sort-Object -Unique)
        }
    }
    $required=@()
    if($Previous){
        if($Previous.ContainsKey('workflowCallers')){$required=@($Previous.workflowCallers.Keys)}
        elseif($Previous.managedFiles.ContainsKey('.github/workflows/main.yaml')){$required=@('.github/workflows/main.yaml')}
        foreach($path in $required){
            if(-not $callers.Contains($path)){throw "Missing or unrecognised OGP caller: $path. Reconcile the caller manually."}
            if($Previous.ContainsKey('workflowCallers')){
                $missing=@($Previous.workflowCallers[$path]|Where-Object {$_ -cnotin @($callers[$path])})
                if($missing.Count){throw "Missing or unrecognised OGP caller reference in ${path}: $($missing -join ', '). Reconcile the caller manually."}
            }
        }
    }
    if(-not $callers.Count){
        if($Previous){throw 'No OGP workflow caller found. Reconcile the caller manually.'}
        $path='.github/workflows/main.yaml'
        if(Test-Path (Join-Path $WorkspaceRoot $path)){throw "Existing site workflow conflicts with starter: $path. Reconcile the caller manually."}
        $expected[$path]=$null
        $files[$path]=[Text.Encoding]::UTF8.GetBytes($Starter)
        $callers[$path]=@('nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml')
    }
    [pscustomobject]@{Files=$files;ExpectedHashes=$expected;Callers=$callers}
}
Export-ModuleMember -Function New-GuideWorkflowCallerPlan
