
param LogAnalyticsWorkspaceName string



resource exsitingLogAnlayticsWS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: LogAnalyticsWorkspaceName
}

output logAnalyticsId string = exsitingLogAnlayticsWS.id
