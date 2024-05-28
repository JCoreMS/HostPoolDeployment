targetScope = 'resourceGroup'

param keyVaultName string
param storageAccountId string
param vmName string
param managementVmPrincipalId string

var storageAcctName = split(storageAccountId, '/')[8]

resource roleAssignVMtoStorageKeyOp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, vmName, 'Storage Account Key Operator Service Role')
  properties: {
    description: 'Storage Account Key Operators are allowed to list and regenerate keys on Storage Accounts (VM: ${vmName})'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '81a9662b-bebf-436f-a333-f67b29880f12')
    principalId: managementVmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignVMtoStorageContrib 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, vmName, 'Contributor')
  properties: {
    description: 'Allows the management VM (${vmName}) to domian join the storage account (${storageAcctName})'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: managementVmPrincipalId
    principalType: 'ServicePrincipal'
  }
}
