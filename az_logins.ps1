# Display current subscription at the top
Write-Host "`nCurrent Azure Subscription:" -ForegroundColor Cyan
az account show --query name -o tsv

# Display menu and get user selection
Write-Host "`nAzure Subscription Switcher" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Cyan
Write-Host "1: Live Operations"
Write-Host "2: Pay-As-You-Go Dev/Test"
Write-Host "3: Quit"
Write-Host "------------------------`n" -ForegroundColor Cyan

$choice = Read-Host "Enter your choice (1, 2, or 3)"

# Define subscription IDs
$liveOpsSubId = "bf0f5d5c-f9e0-43de-86c4-bee26b617b1c"
$devTestSubId = "871033f5-2e8a-4667-b499-5867e6207bc3"

# Process user choice
switch ($choice) {
    "1" {
        Write-Host "`nSwitching to Live Operations subscription..." -ForegroundColor Yellow
        az account set --subscription $liveOpsSubId
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully switched to Live Operations subscription." -ForegroundColor Green
        }
    }
    "2" {
        Write-Host "`nSwitching to Dev/Test subscription..." -ForegroundColor Yellow
        az account set --subscription $devTestSubId
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully switched to Dev/Test subscription." -ForegroundColor Green
        }
    }
    "3" {
        Write-Host "`nExiting script..." -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Host "`nInvalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
        exit 1
    }
}

# Display current subscription
Write-Host "`nCurrent subscription:" -ForegroundColor Cyan
az account show --output table
