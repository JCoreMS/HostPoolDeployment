param storageAcctName string
param location string
param storageSKU string
param storageKind string
param identityStorageSetup object
param keyVault object
param keyVaultKeyName string

// Create Storage Account
resource storageAccountCMKSetup 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAcctName
  location: location
  sku: {
    name: storageSKU
  }
  kind: storageKind
  properties: {
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
        userAssignedIdentity: identityStorageSetup.id
      }
      keySource: 'Microsoft.Keyvault'
      keyvaultproperties: {
        keyname: keyVaultKeyName
        keyvaulturi: endsWith(keyVault.properties.vaultUri, '/')
        ? substring(keyVault.properties.vaultUri, 0, length(keyVault.properties.vaultUri) - 1)
        : keyVault.properties.vaultUri
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
