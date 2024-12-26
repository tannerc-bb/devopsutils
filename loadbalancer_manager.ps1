# Azure DevOps Configuration
$organization = "YOUR_ORGANIZATION"
$project = "YOUR_PROJECT"
$releaseDefinitionId = "YOUR_RELEASE_DEFINITION_ID"
$pat = "YOUR_PERSONAL_ACCESS_TOKEN"

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

# Create base64 encoded authorization header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
}

function Check-ReleasePipelineStatus {
    $url = "https://vsrm.dev.azure.com/$organization/$project/_apis/release/deployments?api-version=6.0"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    
    $activeReleases = $response.value | Where-Object { 
        $_.deploymentStatus -eq "inProgress" -and 
        $_.releaseDefinition.id -eq $releaseDefinitionId 
    }
    
    return $activeReleases.Count -gt 0
}

function Disable-ReleasePipeline {
    $url = "https://vsrm.dev.azure.com/$organization/$project/_apis/release/definitions/$releaseDefinitionId`?api-version=6.0"
    
    # Get current definition
    $definition = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    
    # Disable triggers
    $definition.triggers | ForEach-Object {
        $_.triggerType = "none"
    }
    
    # Update definition
    $body = $definition | ConvertTo-Json -Depth 100
    Invoke-RestMethod -Uri $url -Headers $headers -Method Put -Body $body -ContentType "application/json"
}

function Remove-FromLoadBalancer {
    param (
        [string]$vmName
    )
    
    $config = $vwebConfig[$vmName]
    Write-Host "Removing $($config.name) from load balancer..."
    az network lb address-pool address remove `
        -g $resourceGroup `
        --lb-name $lbName `
        --pool-name $poolName `
        -n $config.name `
        --verbose
}

function Add-ToLoadBalancer {
    param (
        [string]$vmName
    )
    
    $config = $vwebConfig[$vmName]
    Write-Host "Adding $($config.name) to load balancer..."
    az network lb address-pool address add `
        -g $resourceGroup `
        --lb-name $lbName `
        --pool-name $poolName `
        -n $config.name `
        --ip-address $config.ip `
        --subnet $subnet
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
if (Check-ReleasePipelineStatus) {
    Write-Host "Warning: Release pipeline is currently running! Please try again later." -ForegroundColor Red
    exit 1
}

Write-Host "Disabling release pipeline..." -ForegroundColor Yellow
Disable-ReleasePipeline
Write-Host "Release pipeline disabled successfully." -ForegroundColor Green

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
