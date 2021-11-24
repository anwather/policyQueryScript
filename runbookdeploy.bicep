param runbookName string
param runbookUri string
param automationAccountName string
param automationAccountLocation string

resource rb 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: '${automationAccountName}/${runbookName}'
  location: automationAccountLocation
  properties: {
    runbookType: 'PowerShell'
    publishContentLink: {
      uri: runbookUri
    }
  }
}
