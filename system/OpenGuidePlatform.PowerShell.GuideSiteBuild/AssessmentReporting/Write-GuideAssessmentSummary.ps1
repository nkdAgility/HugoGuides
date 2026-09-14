function Write-GuideAssessmentSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Assessment,
        [Parameter(Mandatory)][string]$SummaryPath
    )
    try {
        $schema=Join-Path $PSScriptRoot '../../OpenGuidePlatform.PowerShell.Core/Contracts/assessment.schema.json'
        if(-not (Test-Json -Json ($Assessment|ConvertTo-Json -Depth 100) -SchemaFile $schema -ErrorAction Stop)){
            throw 'Assessment does not satisfy its contract.'
        }
        $markdown=ConvertTo-GuideAssessmentMarkdown $Assessment
        [IO.File]::AppendAllText([IO.Path]::GetFullPath($SummaryPath),"`n"+$markdown+"`n",[Text.UTF8Encoding]::new($false))
        [pscustomobject]@{Channel='ActionsSummary';Outcome='delivered';Code='REPORT_DELIVERED';Message='Assessment appended to the Actions summary.'}
    } catch {
        # Delivery status is separate from the unchanged assessment outcome.
        [pscustomobject]@{Channel='ActionsSummary';Outcome='failed';Code='REPORT_DELIVERY_FAILED';Message=$_.Exception.Message}
    }
}