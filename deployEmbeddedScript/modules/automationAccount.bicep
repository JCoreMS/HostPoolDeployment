param AutomationAccountName string
param Location string


resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' = {
  name: AutomationAccountName
  location: Location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Free'
    }
  }
}
