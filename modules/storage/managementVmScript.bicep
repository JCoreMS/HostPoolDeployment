targetScope = 'resourceGroup'

param domainJoinOUPath string
param domainJoinUserName string
@secure()
param domainJoinUserPassword string
param groupAdmins string
param groupUsers string
param location string
param storageAccountName string
param storageFileShareName string
param storageResourceGroup string
param storageSetupId string
param storageSetupScriptUri array
param storageSetupScriptName string
param tags object
param tenantId string
param timestamp string
param vmName string

var cloud = environment().name
var subscriptionId = subscription().subscriptionId
var scriptParams = '-OuPath ${domainJoinOUPath} -StorageAccountName ${storageAccountName} -StorageAccountResourceGroupName ${storageResourceGroup} -SubscriptionId ${subscriptionId} -TenantId ${tenantId} -AclUsers ${groupUsers} -AclAdmins ${groupAdmins} -StorageFileShareName ${storageFileShareName} -DomainJoinUserPrincipalName ${domainJoinUserName} -DomainJoinPassword ${domainJoinUserPassword} -StorageSetupId ${storageSetupId} -Cloud ${cloud}'

resource virtualMachineStorMgmt 'Microsoft.Compute/virtualMachines@2023-03-01' existing = {
  name: vmName
}

resource extension_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: 'CustomScriptExtension'
  parent: virtualMachineStorMgmt
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      timestamp: timestamp
      fileUris: storageSetupScriptUri
    }
    protectedSettings: {
        commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ${storageSetupScriptName} ${scriptParams}'
        managedIdentity: {
        clientId: storageSetupId
      }
    }
  }
}
