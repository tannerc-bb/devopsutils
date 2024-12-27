param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('disable', 'enable')]
    [string]$Action
)

# Azure Automation account details
$automationAccountName = "all-shared-automationaccount-laqdtbvq5xlpc"
$resourceGroupName = "All-Shared" 
$runbookName = "RefreshTrainingBetenboughDatabase"
$scheduleName = "Daily at 0200 CST"

# Ensure we're logged into Azure
if (-not (Get-AzContext)) {
    Write-Error "Not logged into Azure. Please run Connect-AzAccount first."
    exit 1
}

try {
    if ($Action -eq 'disable') {
        Write-Host "Removing schedule from runbook..."
        
        # Get the registration info for the schedule
        $registration = Get-AzAutomationScheduledRunbook -AutomationAccountName $automationAccountName `
            -ResourceGroupName $resourceGroupName `
            -RunbookName $runbookName `
            -ScheduleName $scheduleName

        if ($registration) {
            # Unregister the schedule from the runbook
            Unregister-AzAutomationScheduledRunbook -AutomationAccountName $automationAccountName `
                -ResourceGroupName $resourceGroupName `
                -RunbookName $runbookName `
                -ScheduleName $scheduleName `
                -Force

            Write-Host "Successfully removed schedule from runbook."
        } else {
            Write-Host "No schedule was found linked to the runbook."
        }
    }
    else {
        Write-Host "Adding schedule to runbook..."
        
        # Register the schedule with the runbook
        Register-AzAutomationScheduledRunbook -AutomationAccountName $automationAccountName `
            -ResourceGroupName $resourceGroupName `
            -RunbookName $runbookName `
            -ScheduleName $scheduleName `
            -RunOn "all-shared-automationaccount-hybridworkergroup-laqdtbvq5xlpc"

        Write-Host "Successfully added schedule to runbook."
    }
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
