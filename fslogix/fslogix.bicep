// https://github.com/Azure/missionlz/blob/main/src/bicep/add-ons/azureVirtualDesktop/modules/fslogix/fslogix.bicep

targetScope = 'subscription'

@description('The resource ID for the storage account hosting the artifacts in Blob storage.')
param artifactsStorageAccountResourceId string

param activeDirectoryConnection string

@allowed([
  'ActiveDirectoryDomainServices'
  'MicrosoftEntraDomainServices'
  'MicrosoftEntraId'
  'MicrosoftEntraIdIntuneEnrollment'
])
@description('The service providing domain services for Azure Virtual Desktop.  This is needed to properly configure the session hosts and if applicable, the Azure Storage Account.')
param activeDirectorySolution string

param automationAccountName string

@allowed([
  'AvailabilitySets'
  'AvailabilityZones'
  'None'
])
@description('The desired availability option when deploying a pooled host pool. The best practice is to deploy to availability zones for the highest resilency and service level agreement.')
param availability string = 'AvailabilityZones'

param azureFilesPrivateDnsZoneResourceId string
param delegatedSubnetId string
param deploymentUserAssignedIdentityClientId string
param dnsServers string

@secure()
@description('The password for the account to domain join the AVD session hosts.')
param domainJoinPassword string = ''

@description('The user principal name for the account to domain join the AVD session hosts.')
param domainJoinUserPrincipalName string = ''

@description('The name of the domain that provides ADDS to the AVD session hosts.')
param domainName string = ''

param encryptionUserAssignedIdentityResourceId string

@description('The file share size(s) in GB for the Fslogix storage solution.')
param fslogixShareSizeInGB int = 100

@allowed([
  'CloudCacheProfileContainer' // FSLogix Cloud Cache Profile Container
  'CloudCacheProfileOfficeContainer' // FSLogix Cloud Cache Profile & Office Container
  'ProfileContainer' // FSLogix Profile Container
  'ProfileOfficeContainer' // FSLogix Profile & Office Container
])
@description('If deploying FSLogix, select the desired type of container for user profiles. https://learn.microsoft.com/en-us/fslogix/concepts-container-types')
param fslogixContainerType string = 'ProfileContainer'

@allowed([
  'AzureNetAppFiles Premium' // ANF with the Premium SKU, 450,000 IOPS
  'AzureNetAppFiles Standard' // ANF with the Standard SKU, 320,000 IOPS
  'AzureFiles Premium' // Azure Files Premium with a Private Endpoint, 100,000 IOPS
  'AzureFiles Standard' // Azure Files Standard with the Large File Share option and a Private Endpoint, 20,000 IOPS
  'None'
])
@description('Enable an Fslogix storage option to manage user profiles for the AVD session hosts. The selected service & SKU should provide sufficient IOPS for all of your users. https://docs.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop-fslogix#performance-requirements')
param fslogixStorageService string = 'AzureFiles Standard'

param hostPoolName string
param hostPoolType string
param keyVaultUri string

@description('The deployment location for the storage resources.')
param location string = deployment().location

param managementVirtualMachineName string
param netAppAccountName string
param netAppCapacityPoolName string

@description('The distinguished name for the target Organization Unit in Active Directory Domain Services.')
param organizationalUnitPath string = ''

@description('Enable backups to an Azure Recovery Services vault.  For a pooled host pool this will enable backups on the Azure file share.  For a personal host pool this will enable backups on the AVD sessions hosts.')
param recoveryServices bool = false

param recoveryServicesVaultName string
param resourceGroupControlPlane string
param resourceGroupManagement string
param resourceGroupStorage string

@description('The array of Security Principals with their object IDs and display names to assign to the AVD Application Group and FSLogix Storage.')
param securityPrincipals array
param securityPrincipalObjectIds array
param securityPrincipalNames array

param serviceName string
param smbServerLocation string
param storageAccountNamePrefix string
param storageAccountNetworkInterfaceNamePrefix string
param storageAccountPrivateEndpointNamePrefix string
param storageEncryptionKeyName string

@maxValue(100)
@minValue(0)
@description('The number of storage accounts to deploy to support sharding across multiple storage accounts. https://docs.microsoft.com/en-us/azure/architecture/patterns/sharding')
param storageCount int = 1

@maxValue(99)
@minValue(0)
@description('The starting number for the names of the storage accounts to support sharding across multiple storage accounts. https://docs.microsoft.com/en-us/azure/architecture/patterns/sharding')
param storageIndex int = 0

param subnet string

@description('The Key / value pairs of metadata for the Azure resource groups and resources.')
param tags object = {}

param timestamp string
param timeZone string
param virtualNetwork string
param virtualNetworkResourceGroup string


var artifactsStorageAccountName = split(artifactsStorageAccountResourceId, '/')[8]
var artifactsUri = 'https://${artifactsStorageAccountName}.blob.${environment().suffixes.storage}/${artifactsContainerName}/'
var fileShareNames = {
  CloudCacheProfileContainer: [
    'profile-containers'
  ]
  CloudCacheProfileOfficeContainer: [
    'office-containers'
    'profile-containers'
  ]
  ProfileContainer: [
    'profile-containers'
  ]
  ProfileOfficeContainer: [
    'office-containers'
    'profile-containers'
  ]
}
var fileShares = fileShareNames[fslogixContainerType]
var netbios = split(domainName, '.')[0]
var storageSku = fslogixStorageService == 'None' ? 'None' : split(fslogixStorageService, ' ')[1]
var storageService = split(fslogixStorageService, ' ')[0]


var tagsAutomationAccounts = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Automation/automationAccounts') ? tags['Microsoft.Automation/automationAccounts'] : {})
var tagsNetAppAccount = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.NetApp/netAppAccounts') ? tags['Microsoft.NetApp/netAppAccounts'] : {})
var tagsPrivateEndpoints = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Network/privateEndpoints') ? tags['Microsoft.Network/privateEndpoints'] : {})
var tagsStorageAccounts = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Storage/storageAccounts') ? tags['Microsoft.Storage/storageAccounts'] : {})
var tagsRecoveryServicesVault = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.recoveryServices/vaults') ? tags['Microsoft.recoveryServices/vaults'] : {})
var tagsVirtualMachines = union({'cm-resource-parent': '${subscription().id}}/resourceGroups/${resourceGroupControlPlane}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'}, contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {})

// Azure NetApp Files for Fslogix
module azureNetAppFiles 'azureNetAppFiles.bicep' = if (storageService == 'AzureNetAppFiles' && contains(activeDirectorySolution, 'DomainServices')) {
  name: 'AzureNetAppFiles_${timestamp}'
  scope: resourceGroup(resourceGroupStorage)
  params: {
    artifactsUri: artifactsUri
    activeDirectoryConnection: activeDirectoryConnection
    delegatedSubnetId: delegatedSubnetId
    dnsServers: dnsServers
    domainJoinPassword: domainJoinPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    domainName: domainName
    fileShares: fileShares
    fslogixContainerType: fslogixContainerType
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    netAppAccountName: netAppAccountName
    netAppCapacityPoolName: netAppCapacityPoolName
    organizationalUnitPath: organizationalUnitPath
    resourceGroupManagement: resourceGroupManagement
    securityPrincipalNames: securityPrincipalNames
    smbServerLocation: smbServerLocation
    storageSku: storageSku
    storageService: storageService
    tagsNetAppAccount: tagsNetAppAccount
    tagsVirtualMachines: tagsVirtualMachines
    timestamp: timestamp
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
  }
}

// Azure Files for FSLogix
module azureFiles 'azureFiles/azureFiles.bicep' = if (storageService == 'AzureFiles' && contains(activeDirectorySolution, 'DomainServices')) {
  name: 'AzureFiles_${timestamp}'
  scope: resourceGroup(resourceGroupStorage)
  params: {
    activeDirectorySolution: activeDirectorySolution
    artifactsUri: artifactsUri
    automationAccountName: automationAccountName
    availability: availability
    azureFilesPrivateDnsZoneResourceId: azureFilesPrivateDnsZoneResourceId
    deploymentUserAssignedIdentityClientId: deploymentUserAssignedIdentityClientId
    domainJoinPassword: domainJoinPassword
    domainJoinUserPrincipalName: domainJoinUserPrincipalName
    enableRecoveryServices: recoveryServices
    encryptionUserAssignedIdentityResourceId: encryptionUserAssignedIdentityResourceId
    fileShares: fileShares
    fslogixContainerType: fslogixContainerType
    fslogixShareSizeInGB: fslogixShareSizeInGB
    fslogixStorageService: fslogixStorageService
    hostPoolType: hostPoolType
    keyVaultUri: keyVaultUri
    location: location
    managementVirtualMachineName: managementVirtualMachineName
    netbios: netbios
    organizationalUnitPath: organizationalUnitPath
    recoveryServicesVaultName: recoveryServicesVaultName
    resourceGroupManagement: resourceGroupManagement
    resourceGroupStorage: resourceGroupStorage
    securityPrincipalNames: securityPrincipalNames
    securityPrincipalObjectIds: securityPrincipalObjectIds
    serviceName: serviceName
    storageAccountNamePrefix: storageAccountNamePrefix
    storageAccountNetworkInterfaceNamePrefix: storageAccountNetworkInterfaceNamePrefix
    storageAccountPrivateEndpointNamePrefix: storageAccountPrivateEndpointNamePrefix
    storageCount: storageCount
    storageEncryptionKeyName: storageEncryptionKeyName
    storageIndex: storageIndex
    storageService: storageService
    storageSku: storageSku
    subnet: subnet
    tagsAutomationAccounts: tagsAutomationAccounts
    tagsPrivateEndpoints: tagsPrivateEndpoints
    tagsRecoveryServicesVault: tagsRecoveryServicesVault
    tagsStorageAccounts: tagsStorageAccounts
    tagsVirtualMachines: tagsVirtualMachines
    timestamp: timestamp
    timeZone: timeZone 
    virtualNetwork: virtualNetwork
    virtualNetworkResourceGroup: virtualNetworkResourceGroup
  }
}

output netAppShares array = storageService == 'AzureNetAppFiles' ? azureNetAppFiles.outputs.fileShares : [
  'None'
]
