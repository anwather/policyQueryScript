# Policy Query Script and Vulnerability Reporting

## Deployment Objects

The following resources will be deployed to the resource group as defined in the script:

- Automation account (managed identity enabled)
- PowerShell modules for the Automation Account - Az.Accounts, Az.Resources, Az.ResourceGraph, Az.Storage
- Automation account variables
- Storage account to hold CSV files
- Containers in the storage account to hold the runbooks, scans, output CSV files
- 2 runbooks to the Automation account
- A Logic App to send reports
- Connection to Azure Storage and Microsoft 365 for the Logic App

## Deployment instructions

1) Ensure the [Bicep](https://github.com/Azure/bicep) is installed and available at $Path
2) Modify the ```deploy.ps1``` script variables as indicated to suit your environment

```
$managementGroupName = "eslz" # Update this value -> This is the root management group used to query the Resource Graph and query policy definitions
$deploymentResourceGroupName = "eslz-mgmt" # Update this value -> Resource group for the resources to be deployed into
$automationAccountName = "eslz-aauto" # Update this value -> Automation account name to be deployed
$storageAccountName = "eslzstor01auto" # Update this value -> Storage account name to be deployed
```
3) Run the ```deploy.ps1``` script to deploy the resources

## Post Deployment

1) Both Logic App connections will need to be authorised
- For the storage connection you need to provide the storage account name and acces key
- For the M365 connection you need to provide authentication
2) Provide an email address in the Logic App activity that reports will be sent to
3) Adjust the frequency for the Logic App to run - i.e. if you are only generating a report weekly, set it to run daily - if no new blobs are available it just skips the trigger
4) Create [Automation Schedules](https://docs.microsoft.com/en-us/azure/automation/shared-resources/schedules) and link to each runbook

**NOTE:** The Logic app only looks at one container in the storage account - you may have to duplicate it and point the second instance to a different container
if you are keeping the scans and policy compliance CSV files separately. 

