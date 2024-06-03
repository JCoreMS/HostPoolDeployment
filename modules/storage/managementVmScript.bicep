
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
param scriptLocation string
param storageSetupScript string
param tags object
param tenantId string
param timestamp string
param vmName string

var cloud = environment().name
var subscriptionId = subscription().subscriptionId
var storageSetupScriptUri = '${scriptLocation}/${storageSetupScript}'


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
      fileUris: [ storageSetupScriptUri ]
      timestamp: timestamp
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ${storageSetupScript} -OuPath ${domainJoinOUPath} -StorageAccountName ${storageAccountName} -StorageAccountResourceGroupName ${storageResourceGroup} -SubscriptionId ${subscriptionId} -TenantId ${tenantId} -AclUsers ${groupUsers} -AclAdmins ${groupAdmins} -StorageFileShareName ${storageFileShareName} -DomainJoinUserPrincipalName ${domainJoinUserName} -DomainJoinPassword ${domainJoinUserPassword} -UserAssignedIdentityClientId ${storageSetupId} -Cloud ${cloud}'
    }
  }
}

