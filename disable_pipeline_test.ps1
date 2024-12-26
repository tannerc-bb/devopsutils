# Azure DevOps Configuration
$organization = "betenboughsystems"
$project = "main"
$releaseDefinitionId = "66"
$pat = "YOUR_PERSONAL_ACCESS_TOKEN"

# Create base64 encoded authorization header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
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

function Verify-PipelineState {
    param (
        [string]$ExpectedState  # 'Enable' or 'Disable'
    )
    
    $url = "https://vsrm.dev.azure.com/$organization/$project/_apis/release/definitions/$releaseDefinitionId`?api-version=6.0"
    
    try {
        $definition = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        $allTriggersCorrect = $true  # Initialize with default value
        
        # Check schedule triggers
        $definition.triggers | ForEach-Object {
            $isEnabled = $_.enabled  # Changed from isEnabled to enabled
            $shouldBeEnabled = ($ExpectedState -eq 'Enable')
            
            if ($isEnabled -ne $shouldBeEnabled) {
                Write-Host "Schedule trigger state mismatch. Expected: $shouldBeEnabled, Actual: $isEnabled" -ForegroundColor Yellow
                $allTriggersCorrect = $false
            }
        }
        
        # Check continuous deployment settings in artifacts
        $definition.artifacts | ForEach-Object {
            if ($_.isPrimary) {
                $cdEnabled = $_.definitionReference.branch.id -eq "master"
                $shouldBeEnabled = ($ExpectedState -eq 'Enable')
                
                if ($cdEnabled -ne $shouldBeEnabled) {
                    Write-Host "Continuous deployment state mismatch for $($_.alias). Expected: $shouldBeEnabled, Actual: $cdEnabled" -ForegroundColor Yellow
                    $allTriggersCorrect = $false
                }
            }
        }
        
        return $allTriggersCorrect
    }
    catch {
        Write-Host "Error verifying pipeline state: $_" -ForegroundColor Red
        return $false
    }
}

function Set-ReleasePipelineState {
    param (
        [string]$State  # 'Enable' or 'Disable'
    )
    
    $url = "https://vsrm.dev.azure.com/$organization/$project/_apis/release/definitions/$releaseDefinitionId`?api-version=6.0"
    
    try {
        # Get current definition
        Write-Host "Getting current pipeline definition..." -ForegroundColor Yellow
        $definition = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        
        # Show current trigger states
        Write-Host "`nCurrent trigger states:" -ForegroundColor Cyan
        Write-Host "Schedule triggers:"
        $definition.triggers | ForEach-Object {
            Write-Host "- Schedule: $($_.schedule.startHours):$($_.schedule.startMinutes) $($_.schedule.timeZoneId)"
        }
        Write-Host "Continuous deployment settings:"
        $definition.artifacts | Where-Object { $_.isPrimary } | ForEach-Object {
            Write-Host "- $($_.alias) branch: $($_.definitionReference.defaultVersionBranch.id)"
        }
        
        # Set the state for schedule triggers
        Write-Host "`n${State}ing schedule triggers..." -ForegroundColor Yellow
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

function Show-Menu {
    Clear-Host
    Write-Host "=== Pipeline Management ==="
    Write-Host "1: Disable Pipeline"
    Write-Host "2: Enable Pipeline"
    Write-Host "Q: Quit"
    Write-Host
}

# Main script
do {
    Show-Menu
    $selection = Read-Host "Please make a selection"
    
    switch ($selection) {
        '1' {
            Write-Host "Checking if release pipeline $releaseDefinitionId is running..." -ForegroundColor Yellow
            if (Check-ReleasePipelineStatus) {
                Write-Host "Warning: Release pipeline is currently running! Please try again later." -ForegroundColor Red
            } else {
                Write-Host "Pipeline is not currently running. Proceeding to disable..." -ForegroundColor Green
                Set-ReleasePipelineState -State 'Disable'
            }
        }
        '2' {
            Write-Host "Proceeding to enable pipeline..." -ForegroundColor Green
            Set-ReleasePipelineState -State 'Enable'
        }
        'Q' { 
            Write-Host "Exiting..." -ForegroundColor Yellow
            return 
        }
        Default { Write-Host "Invalid selection" -ForegroundColor Red }
    }
    
    if ($selection -match '[1-2]') {
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
} while ($selection -ne 'Q')