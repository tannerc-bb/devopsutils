# DevOps Utils

Scripts for managing Azure Load Balancer and Release Pipeline configurations.

## Prerequisites
- Azure CLI installed and logged in (`az login` or using `az_logins.ps1`)
- PowerShell 7 - Please do not use PowerShell 5.1.  The scripts are written for PowerShell 7 and might have issues running on PowerShell 5.1.
- [Azure DevOps PAT](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=Windows) with Release management permissions
    - This will need to be added to the config.json file
    - Permissions required:
        - Release
            - Read
            - Write
            - Execute

## Setup
1. Copy `config.json.example` to `config.json`
2. Add your Azure DevOps PAT to `config.json`
3. Ensure `config.json` is in `.gitignore`

## Usage
- Run the script you want to use with `.\script_name.ps1`
- Follow the prompts to interact with the script

## Scripts
`loadbalancer_manager.ps1`: Interactive menu for managing VMs in the Production load balancer
- Add/remove VMs from the load balancer
- Automatically disables pipeline when removing VMs from the load balancer
- Ensures at least one VM is always in the load balancer
- Re-enables pipeline when adding VMs back to the load balancer

`disable_pipeline_test.ps1`: Interactive menu for enabling/disabling a test pipeline
- Enables/disables a test pipeline
    - Will check if the pipeline is running before enabling/disabling
    - Will enable/disable schedules associated with the pipeline
    - Will enable/disable the branch policy associated with the pipeline

`training_site_refresh.ps1`: Interactive menu for managing training site refresh schedule
- Enables/disables the training site refresh schedule



