param automationAccountName string
param storageAccountName string
param managementGroupName string
param storageAccountResourceGroupName string

var automationVariables = [
  {
    name: 'StorageAccountName'
    value: '"${storageAccountName}"'
  }
  {
    name: 'ManagementGroupName'
    value: '"${managementGroupName}"'
  }
  {
    name: 'StorageAccountResourceGroupName'
    value: '"${storageAccountResourceGroupName}"'
  }
]

var automationModules = [
  {
    name: 'Az.Accounts'
    version: '2.5.2'
  }
  {
    name: 'Az.ResourceGraph'
    version: '0.11.0'
  }
  {
    name: 'Az.Storage'
    version: '3.10.0'
  }
  {
    name: 'Az.Resources'
    version: '4.3.0'
  }
]

var containerNames = [
  'runbooks'
  'scans'
  'output'
]

resource aa 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: automationAccountName
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

@batchSize(1)
module automModules 'automationModules/automationModules.bicep' = [for item in automationModules: {
  name: toLower(replace(item.name, '.', '-'))
  params: {
    automationAccountName: aa.name
    location: resourceGroup().location
    moduleName: item.name
    moduleUrl: 'https://devopsgallerystorage.blob.core.windows.net/packages/${toLower(item.Name)}.${item.version}.nupkg'
  }
  dependsOn: [
    aa
  ]
}]

resource autoVars 'Microsoft.Automation/automationAccounts/variables@2019-06-01' = [for item in automationVariables: {
  name: '${automationAccountName}/${item.name}'
  properties: {
    isEncrypted: true
    value: item.value
  }
  dependsOn: [
    aa
  ]
}]

resource st1 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = [for item in containerNames: {
  name: '${storageAccountName}/default/${item}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    st1
  ]
}]

resource role1 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('automation-storage-contributor')
  scope: st1
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/17d1049b-9a84-46fb-8f53-869881c3d3ab'
    principalId: aa.identity.principalId
  }
  dependsOn: [
    aa
    st1
  ]
}

output storageAccountName string = st1.name
