param storageAccountName string

resource st1 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
}

resource blobConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: 'azureblob-1'
  location: resourceGroup().location
  kind: 'V1'
  properties: {
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/australiasoutheast/managedApis/azureblob'
    }
    displayName: 'blob-connection'
    parameterValueSet: {
      name: 'managedIdentityAuth'
      values: {}
    }
  }
}

resource officeConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'office365-1'
  location: resourceGroup().location
  kind: 'V1'
  properties: {
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/australiasoutheast/managedApis/office365'
      displayName: 'office365Connection'
    }
  }
}

resource workflows_complianceReportEmail_name_resource 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'complianceReportEmail'
  location: resourceGroup().location
  dependsOn: [
    blobConnection
    officeConnection
  ]
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        'When_a_blob_is_added_or_modified_(properties_only)_(V2)': {
          recurrence: {
            frequency: 'Hour'
            interval: 3
          }
          splitOn: '@triggerBody()'
          metadata: {
            JTJmb3V0cHV0: '/output'
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureblob_1\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/v2/datasets/@{encodeURIComponent(encodeURIComponent(\'eslzstor01auto\'))}/triggers/batch/onupdatedfile'
            queries: {
              checkBothCreatedAndModifiedDateTime: false
              folderId: 'JTJmb3V0cHV0'
              maxFileCount: 1
            }
          }
        }
      }
      actions: {
        'Get_blob_content_using_path_(V2)': {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureblob_1\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/v2/datasets/@{encodeURIComponent(encodeURIComponent(\'eslzstor01auto\'))}/GetFileContentByPath'
            queries: {
              inferContentType: true
              path: '@triggerBody()?[\'Path\']'
              queryParametersSingleEncoded: true
            }
          }
        }
        'Send_an_email_(V2)': {
          runAfter: {
            'Get_blob_content_using_path_(V2)': [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            body: {
              Attachments: [
                {
                  ContentBytes: '@{base64(body(\'Get_blob_content_using_path_(V2)\'))}'
                  Name: '@triggerBody()?[\'Name\']'
                }
              ]
              Body: '<p>Please find attached a non-compliant resource list</p>'
              Subject: 'Non-compliant policy objects'
              To: 'anwather@microsoft.com'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/Mail'
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          azureblob_1: {
            connectionId: blobConnection.id
            connectionName: 'azureblob-1'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
            id: blobConnection.properties.api.id
          }
          office365: {
            connectionId: officeConnection.id
            connectionName: 'office365-1'
            id: officeConnection.properties.api.id
          }
        }
      }
    }
  }
}

resource wait 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzurePowerShell'
  location: resourceGroup().location
  name: 'wait'
  properties: {
    scriptContent: 'Start-Sleep -Seconds 60'
    retentionInterval: 'PT1H'
    azPowerShellVersion: '6.4'
  }
  dependsOn: [
    workflows_complianceReportEmail_name_resource
  ]
}

resource blobReader 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('logic-app-blob-reader')
  properties: {
    principalId: workflows_complianceReportEmail_name_resource.identity.principalId
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  }
  dependsOn: [
    wait
  ]
}

output logicAppResourceId string = workflows_complianceReportEmail_name_resource.id
