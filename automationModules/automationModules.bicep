param automationAccountName string
param moduleUrl string
param moduleName string
param location string

resource module 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  name: '${automationAccountName}/${moduleName}'
  location: location
  properties: {
    contentLink: {
      uri: moduleUrl
    }
  }
}
