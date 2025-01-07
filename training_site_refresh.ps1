# Azure Automation account details
$automationAccountName = "all-shared-automationaccount-laqdtbvq5xlpc"
$resourceGroupName = "All-Shared" 
$runbookName = "RefreshTrainingBetenboughDatabase"
$scheduleName = "Daily at 0200 CST"

# Subscription IDs (matching az_logins.ps1)
$liveOpsSubId = "bf0f5d5c-f9e0-43de-86c4-bee26b617b1c"
$devTestSubId = "871033f5-2e8a-4667-b499-5867e6207bc3"

# Function to check and display schedule status
function Show-ScheduleStatus {
    try {
        $registration = Get-AzAutomationScheduledRunbook -AutomationAccountName $automationAccountName `
            -ResourceGroupName $resourceGroupName `
            -RunbookName $runbookName `
            -ScheduleName $scheduleName -ErrorAction SilentlyContinue

        if ($registration) {
            Write-Host "`nCurrent Status: Schedule is" -NoNewline
            Write-Host " ENABLED" -ForegroundColor Green
        } else {
            Write-Host "`nCurrent Status: Schedule is" -NoNewline
            Write-Host " DISABLED" -ForegroundColor Red
        }
    } catch {
        Write-Host "`nCurrent Status:" -NoNewline
        Write-Host " UNKNOWN" -ForegroundColor Red
        Write-Host "Failed to check schedule status: $_" -ForegroundColor Red
    }
}

# Main loop
while ($true) {
    # Show current status
    Show-ScheduleStatus

    # Display menu and get user selection
    Write-Host "`nTraining Site Refresh Schedule Manager" -ForegroundColor Cyan
    Write-Host "--------------------------------" -ForegroundColor Cyan
    Write-Host "WARNING: This script requires PowerShell 7!" -ForegroundColor Yellow
    Write-Host "--------------------------------" -ForegroundColor Cyan
    Write-Host "1: Disable Training Site Refresh Schedule"
    Write-Host "2: Enable Training Site Refresh Schedule"
    Write-Host "Q: Quit"
    Write-Host "--------------------------------`n" -ForegroundColor Cyan

    $choice = Read-Host "Enter your choice (1, 2, or Q)"

    # Convert menu choice to action
    switch ($choice.ToLower()) {
        "1" { $Action = "disable" }
        "2" { $Action = "enable" }
        "q" { 
            Write-Host "`nExiting script..." -ForegroundColor Yellow
            exit 0 
        }
        default {
            Write-Host "`nInvalid choice. Please enter 1, 2, or Q." -ForegroundColor Red
            continue
        }
    }

    # Ensure we're on the right subscription
    try {
        # Try Azure CLI first (in case user is using az_logins.ps1)
        $currentSub = (az account show --query id -o tsv 2>$null)
        if ($currentSub -ne $liveOpsSubId) {
            Write-Host "Switching to Live Operations subscription..."
            az account set --subscription $liveOpsSubId
        }

        # Also ensure Az PowerShell is connected and on right subscription
        if (-not (Get-AzContext)) {
            Write-Host "Not logged into Azure PowerShell. Running Connect-AzAccount..."
            Connect-AzAccount -Subscription $liveOpsSubId
        } else {
            $azContext = Get-AzContext
            if ($azContext.Subscription.Id -ne $liveOpsSubId) {
                Write-Host "Switching Az PowerShell to Live Operations subscription..."
                Set-AzContext -Subscription $liveOpsSubId | Out-Null
            }
        }
    }
    catch {
        Write-Error "Failed to set Azure subscription: $_"
        continue
    }

    try {
        if ($Action -eq 'disable') {
            Write-Host "`nRemoving schedule from runbook..." -ForegroundColor Yellow
            
            $registration = Get-AzAutomationScheduledRunbook -AutomationAccountName $automationAccountName `
                -ResourceGroupName $resourceGroupName `
                -RunbookName $runbookName `
                -ScheduleName $scheduleName

            if ($registration) {
                Unregister-AzAutomationScheduledRunbook -AutomationAccountName $automationAccountName `
                    -ResourceGroupName $resourceGroupName `
                    -RunbookName $runbookName `
                    -ScheduleName $scheduleName `
                    -Force

                Write-Host "Successfully removed schedule from runbook." -ForegroundColor Green
            } else {
                Write-Host "No schedule was found linked to the runbook." -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "`nAdding schedule to runbook..." -ForegroundColor Yellow
            
            Register-AzAutomationScheduledRunbook -AutomationAccountName $automationAccountName `
                -ResourceGroupName $resourceGroupName `
                -RunbookName $runbookName `
                -ScheduleName $scheduleName `
                -RunOn "all-shared-automationaccount-hybridworkergroup-laqdtbvq5xlpc"

            Write-Host "Successfully added schedule to runbook." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "An error occurred: $_"
        continue
    }

    # Pause briefly to show the result before refreshing
    Start-Sleep -Seconds 2
} 