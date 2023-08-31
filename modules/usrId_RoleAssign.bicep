targetScope = 'resourceGroup'

param PostDeployStorName string
param RoleAssignments object
param UserIdentityName string
param UserIdentityPrincipalId string


resource storageAcct 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: PostDeployStorName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for Role in items(RoleAssignments): {
  name: guid(subscription().id, UserIdentityPrincipalId, Role.value.GUID)
  scope: storageAcct
  properties: {
    description: 'Provides User Identity ${UserIdentityName} read access for post deployment scripts.'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', Role.value.GUID)
    principalId: UserIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}]
