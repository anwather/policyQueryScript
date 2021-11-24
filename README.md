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
2) Deploy the solution by modifying the parameter value when deploying - an example is below:

```
.\deploy.ps1 -ManagementGroupName eslz `
        -DeploymentResourceGroupName eslz-auto `
        -AutomationAccountName eslz-aauto `
        -StorageAccountName eslzstor01auto `
        -AutomationAccountLocation australiaeast `
        -StorageAccountLocation australiasoutheast
```

## Post Deployment

1) M365 Logic App connection will need to be authorised
- For the M365 connection you need to provide authentication
2) Provide an email address in the Logic App activity that reports will be sent to
3) Adjust the frequency for the Logic App to run - i.e. if you are only generating a report weekly, set it to run daily - if no new blobs are available it just skips the trigger
4) Create [Automation Schedules](https://docs.microsoft.com/en-us/azure/automation/shared-resources/schedules) and link to each runbook
5) Give the managed identity for the automation account - permission to read policies and access the resource graph at the management group level. Access for the identity on the storage account should be granted by the script

**NOTE:** The Logic app only looks at one container in the storage account - you may have to duplicate it and point the second instance to a different container
if you are keeping the scans and policy compliance CSV files separately. 

