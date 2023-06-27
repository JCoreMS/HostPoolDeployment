targetScope = 'resourceGroup'

param Location string
param PostDeployStorName string
param PostDeployStorRG string
param RoleAssignments object
param UserIdentityName string



resource userIdentityCreate 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: UserIdentityName
  location: Location
}

module roleAssign 'usrId_RoleAssign.bicep' = {
  name: 'linked_assignUserIDRole'
  scope: resourceGroup(PostDeployStorRG)
  params: {
    PostDeployStorName: PostDeployStorName
    UserIdentityName: UserIdentityName
    RoleAssignments: RoleAssignments
    UserIdentityPrincipalId: userIdentityCreate.properties.principalId
  }
}

output userIdentityResId string = userIdentityCreate.id
output userIdentityObjId string = userIdentityCreate.properties.principalId
