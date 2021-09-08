param runbookName string
param runbookUri string
param automationAccountName string

resource rb 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: '${automationAccountName}/${runbookName}'
  location: resourceGroup().location
  properties: {
    runbookType: 'PowerShell'
    publishContentLink: {
      uri: runbookUri
    }
  }
}
