# Azure DevOps Configuration
$organization = "betenboughsystems"
$project = "main"
$releaseDefinitionId = "60" # 60 is the main release pipeline - https://dev.azure.com/betenboughsystems/main/_release?_a=releases&view=mine&definitionId=60
$configPath = Join-Path $PSScriptRoot "config.json"

if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    $pat = $config.pat
} else {
    Write-Host "Error: config.json not found" -ForegroundColor Red
    exit 1
}

# Create base64 encoded authorization header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
}

# Azure CLI Configuration
$resourceGroup = "LiveOperations-eastus2"
$lbName = "FTG_LoadBalancer"
$poolName = "Pool2_Vweb"
$subnet = "/subscriptions/bf0f5d5c-f9e0-43de-86c4-bee26b617b1c/resourceGroups/LiveOperations/providers/Microsoft.Network/virtualNetworks/LiveOperations-vnet/subnets/default"

# VM Configuration
$vwebConfig = @{
    "VWEB6" = @{
        "name" = "vweb6"
        "ip" = "10.128.0.4"
    }
    "VWEB7" = @{
        "name" = "vweb7"
        "ip" = "10.128.0.8"
    }
}

# Add at start of script
$logPath = Join-Path $PSScriptRoot "lb_operations.log"
function Write-Log {
    param($Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Host $Message
}

try {
    Write-Host "Checking Azure CLI login status..." -ForegroundColor Yellow
    $null = az account show
}
catch {
    Write-Host "Error: Not logged into Azure CLI. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

function Set-ReleasePipelineState {
    param (
        [string]$State  # 'Enable' or 'Disable'
    )
    
    $url = "https://vsrm.dev.azure.com/$organization/$project/_apis/release/definitions/$releaseDefinitionId`?api-version=6.0"
    
    try {
        Write-Host "Getting current pipeline definition..." -ForegroundColor Yellow
        $definition = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        
        # Set the state for schedule triggers
        Write-Host "${State}ing schedule triggers..." -ForegroundColor Yellow
        if ($State -eq 'Disable') {
            $definition.triggers = @()  # Remove all triggers
        }
        else {
            # Restore the default schedule if it was removed
            if ($definition.triggers.Count -eq 0) {
                $definition.triggers = @(
                    @{
                        schedule = @{
                            timeZoneId = "Central Standard Time"
                            startHours = 14
                            startMinutes = 0
                            daysToRelease = 31
                        }
                        triggerType = "schedule"
                    }
                )
            }
        }
        
        # Set the state for continuous deployment
        Write-Host "${State}ing continuous deployment..." -ForegroundColor Yellow
        $definition.artifacts | Where-Object { $_.isPrimary } | ForEach-Object {
            if ($State -eq 'Enable') {
                $_.definitionReference.defaultVersionBranch.id = "master"
                $_.definitionReference.defaultVersionBranch.name = "master"
            } else {
                $_.definitionReference.defaultVersionBranch.id = "disabled"
                $_.definitionReference.defaultVersionBranch.name = "disabled"
            }
        }
        
        # Update definition
        $body = $definition | ConvertTo-Json -Depth 100
        Invoke-RestMethod -Uri $url -Headers $headers -Method Put -Body $body -ContentType "application/json"
        
        Write-Host "Pipeline triggers ${State}d successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error ${State}ing pipeline: $_" -ForegroundColor Red
        exit 1
    }
}

function Check-ReleasePipelineStatus {
    $url = "https://vsrm.dev.azure.com/$organization/$project/_apis/release/deployments?api-version=6.0"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        
        $activeReleases = $response.value | Where-Object { 
            $_.deploymentStatus -eq "inProgress" -and 
            $_.releaseDefinition.id -eq $releaseDefinitionId 
        }
        
        return $activeReleases.Count -gt 0
    }
    catch {
        Write-Host "Error checking pipeline status: $_" -ForegroundColor Red
        exit 1
    }
}

function Remove-FromLoadBalancer {
    param (
        [string]$vmName
    )
    
    $config = $vwebConfig[$vmName]
    Write-Host "Removing $($config.name) from load balancer..."
    
    Write-Host "Checking if release pipeline is running..." -ForegroundColor Yellow
    if (Check-ReleasePipelineStatus) {
        Write-Host "Warning: Release pipeline is currently running! Please try again later." -ForegroundColor Red
        return
    }
    
    Write-Host "Disabling pipeline first to prevent accidental deployments..." -ForegroundColor Yellow
    Set-ReleasePipelineState -State 'Disable'
    
    try {
        az network lb address-pool address remove `
            -g $resourceGroup `
            --lb-name $lbName `
            --pool-name $poolName `
            -n $config.name `
            --verbose
    }
    catch {
        Write-Host "Error removing from load balancer: $_" -ForegroundColor Red
        Write-Host "Re-enabling pipeline since operation failed..." -ForegroundColor Yellow
        Set-ReleasePipelineState -State 'Enable'
        return
    }
}

function Add-ToLoadBalancer {
    param (
        [string]$vmName
    )
    
    $config = $vwebConfig[$vmName]
    Write-Host "Adding $($config.name) to load balancer..."
    
    Write-Host "Checking if release pipeline is running..." -ForegroundColor Yellow
    if (Check-ReleasePipelineStatus) {
        Write-Host "Warning: Release pipeline is currently running! Please try again later." -ForegroundColor Red
        return
    }
    
    az network lb address-pool address add `
        -g $resourceGroup `
        --lb-name $lbName `
        --pool-name $poolName `
        -n $config.name `
        --ip-address $config.ip `
        --subnet $subnet
        
    Write-Host "Re-enabling pipeline..." -ForegroundColor Yellow
    Set-ReleasePipelineState -State 'Enable'
}

function Show-Menu {
    Clear-Host
    Write-Host "=== Load Balancer Management ==="
    Write-Host "1: Remove VWEB6 from LB"
    Write-Host "2: Add VWEB6 to LB"
    Write-Host "3: Remove VWEB7 from LB"
    Write-Host "4: Add VWEB7 to LB"
    Write-Host "Q: Quit"
}

# Main script
do {
    Show-Menu
    $selection = Read-Host "Please make a selection"
    
    switch ($selection) {
        '1' { Remove-FromLoadBalancer "VWEB6" }
        '2' { Add-ToLoadBalancer "VWEB6" }
        '3' { Remove-FromLoadBalancer "VWEB7" }
        '4' { Add-ToLoadBalancer "VWEB7" }
        'Q' { return }
        Default { Write-Host "Invalid selection" -ForegroundColor Red }
    }
    
    if ($selection -match '[1-4]') {
        Write-Host "Operation completed. Press any key to continue..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
} while ($selection -ne 'Q')
