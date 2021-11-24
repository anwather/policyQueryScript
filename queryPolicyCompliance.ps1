Connect-AzAccount -Identity

$complianceQuery = @"
policyresources
| where type == 'microsoft.policyinsights/policystates'
| where properties.complianceState == 'NonCompliant'
| join kind = inner (resourcecontainers
| where type == "microsoft.resources/subscriptions"
| project subscriptionId,name) on subscriptionId
| project-away id, name, type, tenantId, kind, location, resourceGroup, managedBy, sku, plan, tags, identity, zones, extendedLocation, subscriptionId1, apiVersion
| project-rename subscriptionName=name1
"@

$managementGroup = Get-AutomationVariable "ManagementGroupName"
$storageAccountName = Get-AutomationVariable "StorageAccountName"
$storageAccountResourceGroupName = Get-AutomationVariable "StorageAccountResourceGroupName"

$objects = @()

do {
    if ($null -eq $SkipToken) {
        $results = Search-AzGraph -Query $complianceQuery -First 1000 -ManagementGroup $managementGroup
        foreach ($res in $results) {
            $objects += $res
        }
        if ($results.SkipToken) {
            $SkipToken = $results.SkipToken
        }
    }
    else {
        $results = Search-AzGraph -Query $complianceQuery -First 1000 -SkipToken $SkipToken -ManagementGroup $managementGroup
        foreach ($res in $results) {
            $objects += $res
        }
        if ($results.SkipToken) {
            $SkipToken = $results.SkipToken
        }
        else {
            $SkipToken = $null
        }
    }
}
until ($null -eq $SkipToken)

$definitions = Get-AzPolicyDefinition

$polMap = @{}

$definitions | Foreach-Object {
    $polMap.Add($_.ResourceId, @{
            Name        = $_.Properties.DisplayName
            Description = $_.Properties.Description
        })
}

$outputObjects = @()

$objects | Foreach-Object {
    $o = [PSCustomObject]@{
        SubscriptionId    = $_.Properties.SubscriptionId
        SubscriptionName  = $_.SubscriptionName
        ResourceType      = $_.Properties.ResourceType 
        ResourceGroup     = $_.Properties.ResourceGroup
        ResourceId        = $_.Properties.ResourceId
        PolicyName        = $polMap[$_.Properties.PolicyDefinitionId].Name
        PolicyDescription = $polMap[$_.Properties.PolicyDefinitionId].Description
    }
    $outputObjects += $o
}

Write-Output "Reporting $($outputObjects.Count) non compliant objects"

$outputObjects | Export-CSV -Path "$env:Temp\output.csv" -NoTypeInformation

$runbookWorkerIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content

Add-AzStorageAccountNetworkRule -ResourceGroupName $storageAccountResourceGroupName -AccountName $storageAccountName -IPAddressOrRange $runbookWorkerIp

Start-Sleep -Seconds 60

$ctx = (Get-AzStorageAccount -ResourceGroupName $storageAccountResourceGroupName -StorageAccountName $storageAccountName).Context

$fileName = "$(Get-Date -Format yyyy_MM_dd_mm)_output.csv"

Set-AzStorageBlobContent -File "$env:Temp\output.csv" -Blob $fileName -Container output -Context $ctx -Force

Remove-AzStorageAccountNetworkRule -ResourceGroupName $storageAccountResourceGroupName -AccountName $storageAccountName -IPAddressOrRange $runbookWorkerIp



