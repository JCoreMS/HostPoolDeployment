targetScope = 'resourceGroup'

param keyVaultName string
param storageAccountId string
param vmName string
param managementVmPrincipalId string

resource roleAssignVMtoStorageKeyOp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, vmName, 'Storage Account Key Operator Service Role')
  properties: {
    description: 'Storage Account Key Operators are allowed to list and regenerate keys on Storage Accounts (VM: ${vmName})'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '81a9662b-bebf-436f-a333-f67b29880f12')
    principalId: managementVmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignVMtoStorageSMBElev 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, vmName, 'Storage File Data SMB Share Elevated Contributor')
  properties: {
    description: 'Allows for read, write, delete and modify NTFS permission access in Azure Storage file shares over SMB (VM: ${vmName})'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a7264617-510b-434b-a828-9731dc254ea7')
    principalId: managementVmPrincipalId
    principalType: 'ServicePrincipal'
  }
}
