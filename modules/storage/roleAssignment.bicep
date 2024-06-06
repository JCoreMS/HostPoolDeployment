targetScope = 'resourceGroup'

param AccountId string
param ApplyToResourceName string
param RoleDefinitionId string
param RoleDescription string
param RoleName string
param Scope string
param ScopeResourceId string
param PrincipalId string
param PrincipalType string = 'ServicePrincipal'

var resourceName = split(ScopeResourceId, '/')[8]

resource existingScopeResourceStorage 'Microsoft.Storage/storageAccounts@2021-06-01' existing = if(Scope == 'StorageAccount') {
  name: resourceName
}

resource existingScopeResourceKeyVault 'Microsoft.KeyVault/Vaults@2021-06-01' existing = if(Scope == 'KeyVault') {
  name: resourceName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(AccountId, ApplyToResourceName, RoleName)
  scope: Scope == 'KeyVault' ? existingScopeResourceKeyVault : existingScopeResourceStorage
  properties: {
    description: RoleDescription
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId)
    principalId: PrincipalId
    principalType: PrincipalType
  }
}
