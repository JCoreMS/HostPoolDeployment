targetScope = 'subscription'

param domainJoinUserName string

@secure()
param domainJoinUserPassword string

param groupAdmins string

param groupUsers string

@description('Expiration time of the key')
param keyExpiration int = dateTimeToEpoch(dateTimeAdd(utcNow(), 'P1Y'))

param keyVaultName string

param location string

param managedIdentityName string

param ouPathStorage string

param ouPathVm string

param privateDNSZoneId string

param privateDNSZoneKvId string

param storageAcctName string

param storageFileShareName string

param storageResourceGroup string

@allowed([
  'ZRS'
  'LRS'
])
param storageRedundancy string

param storageShareSize int

@allowed([
  'Standard'
  'Premium'
])
param storageTier string

param subnetId string
param subscriptionId string = subscription().subscriptionId
param tags object

param timestamp string = utcNow()

param vmName string
param vmAdminUsername string
@secure()
param vmAdminPassword string

var domainJoinFQDN = split(domainJoinUserName, '@')[1]
var storageSKU = '${storageTier}_${storageRedundancy}'
var scriptLocation = 'https://raw.githubusercontent.com/JCoreMS/HostPoolDeployment/master/scripts' // URL with NO trailing slash

var storageKind = storageSKU == 'Premium_LRS' || storageSKU == 'Premium_ZRS' ? 'FileStorage' : 'StorageV2'
var smbSettings = storageSKU == 'Premium_LRS' || storageSKU == 'Premium_ZRS'  // SMB Multichannel is only supported on Premium storage
  ? {
      authenticationMethods: 'Kerberos'
      channelEncryption: 'AES-256-GCM'
      kerberosTicketEncryption: 'AES-256'
      mulitchannel: { enabled: true }
      versions: 'SMB3.0;SMB3.1.1'
    }
  : {
      authenticationMethods: 'Kerberos'
      channelEncryption: 'AES-256-GCM'
      kerberosTicketEncryption: 'AES-256'
      versions: 'SMB3.0;SMB3.1.1'
    }
var storageSetupScript = 'domainJoinStorageAcct.ps1'
var tenantId = subscription().tenantId


resource resourceGroupExisting 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: storageResourceGroup
}

module rgResources 'modules/storage/rgResources.bicep' = {
  name: 'linked_ResourceGroup_Resources'
  scope: resourceGroupExisting
  params: {
    domainJoinUserName: domainJoinUserName
    domainJoinUserPassword: domainJoinUserPassword
    location: location
    tags: tags
    keyExpiration: keyExpiration
    keyVaultName: keyVaultName
    managedIdentityName: managedIdentityName
    storageAcctName: storageAcctName
    storageSKU: storageSKU
    subnetId: subnetId
    tenantId: tenantId
    timestamp: timestamp
    groupAdmins: groupAdmins
    groupUsers: groupUsers
    ouPathStorage: ouPathStorage
    ouPathVm: ouPathVm
    privateDNSZoneId: privateDNSZoneId
    privateDNSZoneKvId: privateDNSZoneKvId
    domainJoinFQDN: domainJoinFQDN
    scriptLocation: scriptLocation
    smbSettings: smbSettings
    storageFileShareName: storageFileShareName
    storageKind: storageKind
    storageResourceGroup: storageResourceGroup
    storageSetupScript: storageSetupScript
    storageShareSize: storageShareSize
    subscriptionId: subscriptionId
    vmAdminPassword: vmAdminPassword
    vmAdminUsername: vmAdminUsername
    vmName: vmName
  }
  dependsOn: [resourceGroupExisting]
}








