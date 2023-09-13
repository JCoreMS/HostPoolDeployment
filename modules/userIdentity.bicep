targetScope = 'resourceGroup'

param Location string
param PostDeployOption bool
param PostDeployStorName string
param PostDeployStorRG string
param RoleAssignments object
param Tags object
param UserIdentityName string



resource userIdentityCreate 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if(PostDeployOption) {
  name: UserIdentityName
  location: Location
  tags: contains(Tags, 'Microsoft.ManagedIdentity/userAssignedIdentities') ? Tags['Microsoft.ManagedIdentity/userAssignedIdentities'] : {}
}

module roleAssign 'usrId_RoleAssign.bicep' = if(PostDeployOption) {
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
