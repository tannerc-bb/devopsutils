# DevOps Utils

Scripts for managing Azure Load Balancer and Release Pipeline configurations.

## Prerequisites
- Azure CLI installed and logged in (`az login`)
- PowerShell 5.1 or higher
- Azure DevOps PAT with Release management permissions
    - This will need to be added to the config.json file

## Setup
1. Copy `config.json.example` to `config.json`
2. Add your Azure DevOps PAT to `config.json`
3. Ensure `config.json` is in `.gitignore`

## Usage
- `loadbalancer_manager.ps1`: Interactive menu for managing VMs in load balancer
- `disable_pipeline_test.ps1`: Interactive menu for managing pipeline triggers
- `training_site_refresh.ps1`: Interactive menu for managing training site refresh schedule

## Safety Features
- Checks if pipeline is running before operations
- Automatically disables pipeline when removing VMs from the load balancer
- Ensures at least one VM is always in the load balancer
- Re-enables pipeline when adding VMs back to the load balancer
