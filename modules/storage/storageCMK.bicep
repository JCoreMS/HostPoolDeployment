
targetScope = 'resourceGroup'

param domainFQDN string
param domainGUID string
param identityOption string
param identityStorageSetupId string
param keyVaultKeyName string
param keyVaultUri string
param location string
param storageAcctName string
param storageKind string
param storageSKU string
param tags object

var activeDirectoryProperties = identityOption == 'AADKERB' ? {
  domainName: domainFQDN
  netBiosDomainName: ' '
  forestName: ' '
  domainGuid: domainGUID
  domainSid: ' '
  azureStorageSid: ' '
  } : null

// Create Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAcctName
  location: location
  tags: tags
  sku: {
    name: storageSKU
  }
  kind: storageKind
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityStorageSetupId}': {}
    }
  }
  properties: {
    azureFilesIdentityBasedAuthentication: activeDirectoryProperties != null ? {
      directoryServiceOptions: identityOption
      activeDirectoryProperties: activeDirectoryProperties
    } : null
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    accessTier: 'Hot'
    publicNetworkAccess: 'Disabled'
    allowCrossTenantReplication: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    dnsEndpointType: 'Standard'
    largeFileSharesState: 'Enabled'
    encryption: {
      identity: {
        userAssignedIdentity: identityStorageSetupId
      }
      keySource: 'Microsoft.Keyvault'
      keyvaultproperties: {
        keyname: keyVaultKeyName
        keyvaulturi: keyVaultUri
      }
      services: {
        file: {
          enabled: true
        }
      }
      requireInfrastructureEncryption: false
    }
  }
}
