function Save-GuidePdfReceipt {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][Collections.IDictionary]$Policy,[Parameter(Mandatory)]$Receipt,[Parameter(Mandatory)][string]$ReceiptPath,[ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedReceiptSha256)
    if($Receipt.schemaVersion -ne 1 -or $Receipt.EnvironmentSha256 -notmatch '^[a-fA-F0-9]{64}$'){throw 'A generation receipt requires the approved EnvironmentSha256; do not invent environment evidence.'}
    $pdf=Resolve-GuideWorkspacePath $WorkspaceRoot $Receipt.Path
    if((Get-FileHash -LiteralPath $pdf).Hash -ne $Receipt.Sha256){throw 'PDF no longer matches its generation receipt.'}
    Assert-GuideWriteAllowed $Policy $ReceiptPath
    $path=Resolve-GuideWorkspacePath $WorkspaceRoot $ReceiptPath
    if($path -eq $pdf -or $ReceiptPath -notmatch '\.json$'){throw 'Use a separate JSON file for the receipt.'}
    if(Test-Path -LiteralPath $path){
        if(-not $ExpectedReceiptSha256 -or (Get-FileHash -LiteralPath $path).Hash -ne $ExpectedReceiptSha256){throw 'Receipt already exists or changed; provide its reviewed ExpectedReceiptSha256.'}
    }elseif($ExpectedReceiptSha256){throw 'Reviewed receipt is missing.'}
    if($PSCmdlet.ShouldProcess($path,'Save PDF generation evidence')){
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))|Out-Null
        $temporary=$path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
        try{
            [IO.File]::WriteAllText($temporary,($Receipt|ConvertTo-Json -Depth 40))
            if($ExpectedReceiptSha256){
                if((Get-FileHash -LiteralPath $path).Hash -ne $ExpectedReceiptSha256){throw 'Receipt changed before replacement.'}
                [IO.File]::Replace($temporary,$path,[System.Management.Automation.Language.NullString]::Value)
            }else{[IO.File]::Move($temporary,$path)}
        }finally{if([IO.File]::Exists($temporary)){[IO.File]::Delete($temporary)}}
        [pscustomobject]@{Path=$ReceiptPath;Sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
    }
}
function Get-GuidePdfReceipts {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][Collections.IDictionary]$Policy,[Parameter(Mandatory)]$Requirements)
    $findings=[Collections.Generic.List[object]]::new();$records=[Collections.Generic.List[object]]::new()
    $policyHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($Policy|ConvertTo-Json -Depth 40 -Compress)))).ToLowerInvariant()
    foreach($download in $Requirements.Required){
        if($download.Handling -ne 'generated'){$records.Add([pscustomobject]@{Path=$download.SourcePath;State='preserved';Handling=$download.Handling});continue}
        try{
            if(-not $download.GenerationReceipt){throw 'Declare generationReceipt.path and its approved environmentSha256, then retain the generation receipt.'}
            $receiptPath=Resolve-GuideWorkspacePath $WorkspaceRoot $download.GenerationReceipt.path
            $receipt=Get-Content -LiteralPath $receiptPath -Raw -ErrorAction Stop|ConvertFrom-Json
            if($receipt.schemaVersion -ne 1 -or $receipt.Path -cne $download.SourcePath -or $receipt.Guide -cne $download.Guide -or $receipt.Edition -cne $download.Edition -or $receipt.Language -cne $download.Language){throw 'Receipt does not identify this guide, edition, language and PDF.'}
            if($receipt.Sha256 -cne $download.Sha256 -or $receipt.ConfigurationSha256 -cne $policyHash){throw 'PDF bytes or reviewed policy differ from generation evidence.'}
            if($receipt.EnvironmentSha256 -cne $download.GenerationReceipt.environmentSha256){throw 'Generation environment differs from the approved policy digest.'}
            $sources=@($receipt.Inputs|Where-Object Path -CEQ $download.SourceDocument)
            if($sources.Count -ne 1){throw 'Receipt must include the selected language source document.'}
            foreach($inputFile in $receipt.Inputs){
                if($inputFile.Sha256 -cnotmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath (Resolve-GuideWorkspacePath $WorkspaceRoot $inputFile.Path)).Hash.ToLowerInvariant() -cne $inputFile.Sha256){throw "Generation input changed: $($inputFile.Path)"}
            }
            foreach($name in @('pandoc','xelatex')){
                $tools=@($receipt.Toolchain|Where-Object Tool -CEQ $name)
                if($tools.Count -ne 1 -or -not $tools[0].Available -or -not $tools[0].Version -or $tools[0].ExecutableSha256 -cnotmatch '^[a-f0-9]{64}$'){throw "Receipt lacks generation tool evidence for $name."}
            }
            $records.Add([pscustomobject]@{Path=$download.SourcePath;State='verified';ReceiptPath=$download.GenerationReceipt.path;ReceiptSha256=(Get-FileHash -LiteralPath $receiptPath).Hash.ToLowerInvariant();Receipt=$receipt})
        }catch{
            $findings.Add([pscustomobject]@{Code='PDF_GENERATION_EVIDENCE_INVALID';Path=$download.SourcePath;Message=$_.Exception.Message})
            $records.Add([pscustomobject]@{Path=$download.SourcePath;State='blocked'})
        }
    }
    [pscustomobject]@{SchemaVersion=1;Outcome=if($findings.Count){'blocked'}else{'pass'};Records=$records.ToArray();Findings=$findings.ToArray()}
}
