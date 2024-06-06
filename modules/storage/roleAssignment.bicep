targetScope = 'resourceGroup'

param AccountId string
param ApplyToResourceName string
param RoleDefinitionId string
param RoleDescription string
param RoleName string
param PrincipalId string
param PrincipalType string = 'ServicePrincipal'
param Timestamp string = utcNow('yyyy-MM-ddTHH:mm:ssZ')


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(AccountId, ApplyToResourceName, RoleName, Timestamp)
  properties: {
    description: RoleDescription
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId)
    principalId: PrincipalId
    principalType: PrincipalType
  }
}
