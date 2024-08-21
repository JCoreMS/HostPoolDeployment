targetScope = 'subscription'

param _artifactsLocation string = ''
param _artifactsLocationSasToken string = ''


param domainGUID string = '00000000-0000-0000-0000-000000000000'

param domainJoinUserName string = ''

@secure()
param domainJoinUserPassword string = ''

param domainFQDN string = ''

param groupAdminsName string
param groupAdminsGuid string

param groupUsersName  string
param groupUsersGuid string

@allowed([
  'AD'
  'AADKERB'
  'AADDS'
  'None'
])
param identityOption string

@description('Expiration time of the key')
param keyExpiration int = dateTimeToEpoch(dateTimeAdd(utcNow(), 'P1Y'))

param keyVaultName string

param location string

param managedIdentityName string

param ouPathStorage string = ''

param ouPathVm string = ''

param privateDNSZoneId string

param privateDNSZoneKvId string

param privateEndPointPrefix string

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

param vmsubnetId string = ''
param storsubnetId string
param subscriptionId string = subscription().subscriptionId
param tags object

param timestamp string = utcNow()

param vmName string = ''
param vmAdminUsername string = ''
@secure()
param vmAdminPassword string = ''

// var domainJoinFQDN = domainJoinUserName != '' ? split(domainJoinUserName, '@')[1] : null
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
  name: 'linked_ResourceGroup_Resources-${storageAcctName}'
  scope: resourceGroupExisting
  params: {
    domainFQDN: domainFQDN
    domainGUID: domainGUID
    domainJoinUserName: domainJoinUserName
    domainJoinUserPassword: domainJoinUserPassword
    identityOption: identityOption
    location: location
    tags: tags
    keyExpiration: keyExpiration
    keyVaultName: keyVaultName
    managedIdentityName: managedIdentityName
    storageAcctName: storageAcctName
    storageSKU: storageSKU
    vmsubnetId: vmsubnetId
    tenantId: tenantId
    timestamp: timestamp
    groupAdminsName: groupAdminsName
    groupUsersName: groupUsersName
    groupAdminsGuid: groupAdminsGuid
    groupUsersGuid: groupUsersGuid
    ouPathStorage: ouPathStorage
    ouPathVm: ouPathVm
    privateDNSZoneId: privateDNSZoneId
    privateDNSZoneKvId: privateDNSZoneKvId
    privateEndPointPrefix: privateEndPointPrefix
    scriptLocation: scriptLocation
    smbSettings: smbSettings
    storageFileShareName: storageFileShareName
    storageKind: storageKind
    storageResourceGroup: storageResourceGroup
    storageSetupScript: storageSetupScript
    storageShareSize: storageShareSize
    storsubnetId: storsubnetId
    subscriptionId: subscriptionId
    vmAdminPassword: vmAdminPassword
    vmAdminUsername: vmAdminUsername
    vmName: vmName
  }
  dependsOn: [resourceGroupExisting]
}








