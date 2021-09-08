$managementGroupName = "eslz"
$deploymentResourceGroupName = "eslz-mgmt"
$automationAccountName = "eslz-aauto"
$storageAccountName = "eslzstor01auto"

$deployment = New-AzResourceGroupDeployment -ResourceGroupName $deploymentResourceGroupName `
    -TemplateFile .\azuredeploy.bicep `
    -StorageAccountName $storageAccountName `
    -AutomationAccountName $automationAccountName `
    -ManagementGroupName $managementGroupName `
    -StorageAccountResourceGroupName $deploymentResourceGroupName `
    -Verbose

$ctx = (Get-AzStorageAccount -ResourceGroupName $deploymentResourceGroupName -StorageAccountName $deployment.outputs.storageAccountName.Value).Context

$runbooks = @("queryPolicyCompliance", "queryVulnerabilities")

$runbooks | ForEach-Object {
    Set-AzStorageBlobContent -File ".\$_.ps1" -Blob "$_.ps1" -Container runbooks -Context $ctx -Force

    $token = New-AzStorageBlobSASToken -Blob "$_.ps1" -Container runbooks -Permission rl -ExpiryTime (Get-Date).AddMinutes(5) -Context $ctx -FullUri

    New-AzResourceGroupDeployment -ResourceGroupName $deploymentResourceGroupName `
        -TemplateFile .\runbookdeploy.bicep `
        -RunbookName $_ `
        -RunbookUri $token `
        -AutomationAccountName $automationAccountName `
        -Verbose
}

New-AzResourceGroupDeployment -ResourceGroupName $deploymentResourceGroupName -TemplateFile .\logicApp.bicep -Verbose

