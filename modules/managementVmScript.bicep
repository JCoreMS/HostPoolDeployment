
param domainJoinOUPath string
param domainJoinUserName string
@secure()
param domainJoinUserPassword string
param groupAdmins string
param groupUsers string
param kerberosEncryptionType string
param location string
param storageAccountName string
param storageFileShareName string
param storageResourceGroup string
param scriptLocation string
param storageSetupScript string
param tags object
param vmName string


var subscriptionId = subscription().subscriptionId
var tenantId = subscription().tenantId
var cloudEnvironment = environment().name
var storageSetupScriptUri = '${scriptLocation}/${storageSetupScript}'


resource virtualMachineStorMgmt 'Microsoft.Compute/virtualMachines@2023-03-01' existing = {
  name: vmName
}

resource vm_RunScriptDomJoinStorage 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'vm_RunScriptDomJoinStorage'
  parent: virtualMachineStorMgmt
  location: location
  tags: tags
  properties: {
    treatFailureAsDeploymentFailure: true
    asyncExecution: false
    runAsUser: split(domainJoinUserName, '@')[0]
    runAsPassword: domainJoinUserPassword
    parameters: [
      {
        name: 'File'
        value: storageSetupScript
      }
      {
        name: 'Environment'
        value: cloudEnvironment
      }
      {
        name: 'KerberosEncryptionType'
        value: kerberosEncryptionType
      }
      {
        name: 'OuPath'
        value: domainJoinOUPath
      }
      {
        name: 'StorageAccountName'
        value: storageAccountName
      }
      {
        name: 'StorageAccountResourceGroupName'
        value: storageResourceGroup
      }
      {
        name: 'SubscriptionId'
        value: subscriptionId
      }
      {
        name: 'TenantId'
        value: tenantId
      }
      {
        name: 'AclUsers'
        value: groupUsers
      }
      {
        name: 'AclAdmins'
        value: groupAdmins
      }
      {
        name: 'StorageFileShareName'
        value: storageFileShareName
      }
    ]
    source: {
      scriptUri: storageSetupScriptUri
    }
  }
}
