targetScope = 'resourceGroup'

param AccountId string
param ApplyToResourceName string
param RoleDefinitionId string
param RoleDescription string
param RoleName string
param PrincipalId string
param PrincipalType string = 'ServicePrincipal'


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(AccountId, ApplyToResourceName, RoleName)
  properties: {
    description: RoleDescription
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId)
    principalId: PrincipalId
    principalType: PrincipalType
  }
}
