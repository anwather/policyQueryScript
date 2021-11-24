Connect-AzAccount -Identity

function ConvertPSObjectToHashtable {
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) { ConvertPSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }

            $hash
        }
        else {
            $InputObject
        }
    }
}

$query = @"
securityresources
 | where type == "microsoft.security/assessments"
 | where * contains "vulnerabilities in your virtual machines"
 | summarize by assessmentKey=name //the ID of the assessment
 | join kind=inner (
    securityresources
     | where type == "microsoft.security/assessments/subassessments"
     | extend assessmentKey = extract(".*assessments/(.+?)/.*",1,  id)
 ) on assessmentKey
| join kind = inner (resourcecontainers
| where type == "microsoft.resources/subscriptions"
| project subscriptionId,name) on subscriptionId
| project assessmentKey, subassessmentKey=name, id, parse_json(properties), resourceGroup, subscriptionId, tenantId, subscriptionName=name1
| extend description = properties.description,
         displayName = properties.displayName,
         resourceId = properties.resourceDetails.id,
         resourceSource = properties.resourceDetails.source,
         category = properties.category,
         severity = properties.status.severity,
         code = properties.status.code,
         timeGenerated = properties.timeGenerated,
         remediation = properties.remediation,
         impact = properties.impact,
         vulnId = properties.id,
         additionalData = properties.additionalData
| project-away properties, assessmentKey, subassessmentKey, id, tenantId
"@

$managementGroup = Get-AutomationVariable "ManagementGroupName"
$storageAccountName = Get-AutomationVariable "StorageAccountName"
$storageAccountResourceGroupName = Get-AutomationVariable "StorageAccountResourceGroupName"

$ctx = (Get-AzStorageAccount -ResourceGroupName $storageAccountResourceGroupName -StorageAccountName $storageAccountName).Context

$objects = @()

do {
    if ($null -eq $SkipToken) {
        $results = Search-AzGraph -Query $query -First 1000 -ManagementGroup $managementGroup
        foreach ($res in $results) {
            $objects += $res
        }
        if ($results.SkipToken) {
            $SkipToken = $results.SkipToken
        }
    }
    else {
        $results = Search-AzGraph -Query $query -First 1000 -SkipToken $SkipToken -ManagementGroup $managementGroup
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

$computerObjects = $objects | Group-Object -Property resourceId | Select-Object -ExpandProperty Name

Write-Output "Discovered $($computerObjects.Count) assessments"

$runbookWorkerIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content

Add-AzStorageAccountNetworkRule -ResourceGroupName $storageAccountResourceGroupName -AccountName $storageAccountName -IPAddressOrRange $runbookWorkerIp

Start-Sleep -Seconds 60

$computerObjects | Foreach-Object {
    $outputObjects = @()
    $objects | Where-Object resourceId -eq $_ | Foreach-Object {
        $o = [PSCustomObject]@{}
        $hashObject = $_ | ConvertPSObjectToHashtable
        $hashObject.GetEnumerator() | Foreach-Object {
            $o | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value
        }
        $outputObjects += $o
    }
    $fileName = "$($_.Split("/")[-1])_$($_.Split("/")[2])_$($_.Split("/")[4].ToLower())_$(Get-Date -Format yyyy_MM_dd_mm)_output.csv"
    $outputObjects | Export-CSV -Path $env:Temp\$fileName -NoTypeInformation
    Set-AzStorageBlobContent -File "$env:Temp\$fileName" -Blob $fileName -Container scans -Context $ctx -Force
}

Remove-AzStorageAccountNetworkRule -ResourceGroupName $storageAccountResourceGroupName -AccountName $storageAccountName -IPAddressOrRange $runbookWorkerIp