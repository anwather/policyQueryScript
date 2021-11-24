<#
.SYNOPSIS
    Deploys the solution as at https://github.com/anwather/policyQueryScript
.DESCRIPTION
    See README.md for more details
.EXAMPLE
    PS C:\> deploy.ps1 -ManagementGroupName eslz `
        -DeploymentResourceGroupName eslz-auto `
        -AutomationAccountName eslz-aauto `
        -StorageAccountName eslzstor01auto `
        -AutomationAccountLocation australiaeast `
        -StorageAccountLocation australiasoutheast
.PARAMETER ManagementGroupName
    This is the root management group used to query the Resource Graph and query policy definitions
.PARAMETER DeploymentResourceGRoupName
    Resource group for the resources to be deployed into
.PARAMETER AutomationAccountName
    New automation account to be created
.PARAMETER StorageAccountName
    New storage account to be created
.PARAMETER AutomationAccountLocation
    Location for automation account
.PARAMETER StorageAccountLocation
    Location for storage account
    The storage account and automation account should not be in the same region
#>

Param(
    [Parameter(Mandatory = $true)]
    [string]$ManagementGroupName,
    [Parameter(Mandatory = $true)]
    [string]$DeploymentResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$AutomationAccountName,
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,
    [Parameter(Mandatory = $true)]
    [string]$AutomationAccountLocation,
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountLocation
)

if ($AutomationAccountLocation -eq $storageAccountLocation) {
    Write-Error "Storage account and automation account cannot be in the same location"
    exit
}

try {
    bicep --version
}
catch {
    Write-Error "Ensure Bicep is available 'https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#install-manually'"
    exit
}



New-AzResourceGroupDeployment -ResourceGroupName $deploymentResourceGroupName `
    -TemplateFile .\azuredeploy.bicep `
    -StorageAccountName $storageAccountName `
    -AutomationAccountName $automationAccountName `
    -ManagementGroupName $managementGroupName `
    -StorageAccountResourceGroupName $deploymentResourceGroupName `
    -StorageAccountLocation $storageAccountLocation `
    -AutomationAccountLocation $automationAccountLocation `
    -Verbose

$ctx = (Get-AzStorageAccount -ResourceGroupName $deploymentResourceGroupName -StorageAccountName $storageAccountName).Context

$runbooks = @("queryPolicyCompliance", "queryVulnerabilities")

$runbooks | ForEach-Object {
    Set-AzStorageBlobContent -File ".\$_.ps1" -Blob "$_.ps1" -Container runbooks -Context $ctx -Force

    $token = New-AzStorageBlobSASToken -Blob "$_.ps1" -Container runbooks -Permission rl -ExpiryTime (Get-Date).AddMinutes(5) -Context $ctx -FullUri

    New-AzResourceGroupDeployment -ResourceGroupName $deploymentResourceGroupName `
        -TemplateFile .\runbookdeploy.bicep `
        -RunbookName $_ `
        -RunbookUri $token `
        -AutomationAccountName $automationAccountName `
        -AutomationAccountLocation $automationAccountLocation `
        -Verbose
}

Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $deploymentResourceGroupName -Name $storageAccountName -DefaultAction Deny

$deployment = New-AzResourceGroupDeployment -ResourceGroupName $deploymentResourceGroupName `
    -TemplateFile .\logicApp.bicep `
    -Verbose `
    -StorageAccountName $storageAccountName

$resourceAccessRule = @{
    TenantId   = (Get-AzContext).Tenant
    ResourceId = $deployment.outputs.logicAppResourceId.Value
}

Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $deploymentResourceGroupName -Name $storageAccountName -ResourceAccessRule $resourceAccessRule

