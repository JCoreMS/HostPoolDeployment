targetScope = 'resourceGroup'

param domainJoinUserName string

@secure()
param domainJoinUserPassword string

param domainJoinFQDN string
param groupAdmins string
param groupUsers string
param keyExpiration int
param keyVaultName string
param location string
param managedIdentityName string
param ouPathStorage string
param ouPathVm string
param privateDNSZoneId string
param privateDNSZoneKvId string
param scriptLocation string
param smbSettings object
param storageAcctName string
param storageFileShareName string
param storageKind string
param storageResourceGroup string
param storageShareSize int
param storageSetupScript string
param storageSKU string
param subnetId string
param subscriptionId string
param tags object
param tenantId string
param timestamp string

@secure()
param vmAdminPassword string

param vmAdminUsername string
param vmName string



// Create User Assigned Managed Identity
resource identityStorageSetup 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

// Create Key Vault for CMK for Storage Account (For Scale only single Key Vault per Storage Account recommended)
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enablePurgeProtection: true
    enableSoftDelete: true
    enabledForDiskEncryption: true
    enableRbacAuthorization: true
    enabledForDeployment: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    publicNetworkAccess: 'Disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: tenantId
  }
}

// Create Key Vault Key for Storage Account
resource keyVaultKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: '${storageAcctName}-${timestamp}'
  tags: tags
  properties: {
    attributes: {
      enabled: true
      exp: keyExpiration
    }
    kty: 'RSA'
    keySize: 2048
    curveName: 'P-256'
    keyOps: [
      'encrypt'
      'decrypt'
      'sign'
      'verify'
      'wrapKey'
      'unwrapKey'
    ]
    rotationPolicy: {
      attributes: {
        expiryTime: 'P1Y'
      }
      lifetimeActions: [
        {
          action: { type: 'rotate' }
          trigger: { timeBeforeExpiry: 'P90D' }
        }
      ]
    }
  }
}


// Assign Managed Identity to Key Vault
resource assignIdentity2Vault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, 'assignIdentity2Vault')
  scope: keyVault
  properties: {
    description: 'Provides User Identity ${identityStorageSetup.name} access to Key Vault ${keyVault.name}'
    principalId: identityStorageSetup.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'e147488a-f6f5-4113-8e2d-b22465e65bf6'
    ) // Key Vault Crypto Service Encryption User
  }
  dependsOn: [
    keyVaultKey
    keyvaultPvtEndpoint
  ]
}

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
      '${identityStorageSetup.id}': {}
    }
  }
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
        keyname: keyVaultKey.name
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
  dependsOn: [
    assignIdentity2Vault
  ]
}

// Private Endpoint for Storage Account
resource storagePvtEndpoint 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: 'pep-${storageAcctName}'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pep-${storageAcctName}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
  dependsOn:[
    keyVaultKey
  ]
}

// Private Endpoint for Storage Account
resource keyvaultPvtEndpoint 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: 'pep-${keyVaultName}'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pep-${keyVaultName}'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
  dependsOn:[
    keyVaultKey
  ]
}

resource storageFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: '${storageAccount.name}/default/${storageFileShareName}'
  properties: {
    shareQuota: storageShareSize
    enabledProtocols: 'SMB'
  }
  dependsOn: [
    storageFileService
  ]
}

// Create Management Virtual Machine and domain join storage
//     System Managed Identity to access storage

module managementVm 'managementVm.bicep' = {
  name: 'linked_managementVm'
  scope: resourceGroup(storageResourceGroup)
  params: {
    assignedIdentityId: identityStorageSetup.id
    domainJoinFQDN: domainJoinFQDN
    domainJoinOUPath: ouPathStorage
    domainJoinUserName: domainJoinUserName
    domainJoinUserPassword: domainJoinUserPassword
    location: location
    subnetId: subnetId
    vmName: vmName
    tags: tags
    vmAdminPassword: vmAdminPassword
    vmAdminUsername: vmAdminUsername
  }
  dependsOn: [
    storageAccount
    storageFileShare
  ]
}

resource vaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: 'vaultPrivateDnsZoneGroup'
  parent: keyvaultPvtEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dnsConfig'
        properties: {
          privateDnsZoneId: privateDNSZoneKvId
        }
      }
    ]
  }
}

resource storageFileService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    protocolSettings: {
      smb: smbSettings
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
  dependsOn: [
    storagePvtEndpoint
  ]
}



resource filePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: 'filePrivateDnsZoneGroup'
  parent: storagePvtEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dnsConfig'
        properties: {
          privateDnsZoneId: privateDNSZoneId
        }
      }
    ]
  }
}

// Assign Managed Identity to Storage Account
resource assignIdentity2StorageSMB 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, 'assignIdentity2StorageSMB')
  scope: storageAccount
  properties: {
    description: 'Provides User Identity ${identityStorageSetup.name} access to Key Vault ${keyVault.name}'
    principalId: identityStorageSetup.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'a7264617-510b-434b-a828-9731dc254ea7'
    ) // Storage File Data SMB Share Elevated Contributor
  }
}

// Assign Managed Identity to Storage Account
resource assignIdentity2StorageContrib 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, 'assignIdentity2StorageRead')
  scope: storageAccount
  properties: {
    description: 'Provides User Identity ${identityStorageSetup.name} access to Key Vault ${keyVault.name}'
    principalId: identityStorageSetup.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '17d1049b-9a84-46fb-8f53-869881c3d3ab'
    ) // Storage Account Contributor Role
  }
}


module managementVmScript 'managementVmScript.bicep' = {
  name: 'linked_managementVMscript'
  params: {
    domainJoinOUPath: ouPathVm
    domainJoinUserName: domainJoinUserName
    domainJoinUserPassword: domainJoinUserPassword
    location: location
    storageSetupScriptUri: ['${scriptLocation}/${storageSetupScript}']
    storageSetupScriptName: storageSetupScript
    storageSetupId: identityStorageSetup.properties.clientId
    storageAccountName: storageAcctName
    storageFileShareName: storageFileShareName
    storageResourceGroup: storageResourceGroup
    subscriptionId: subscriptionId
    tags: tags
    tenantId: tenantId
    timestamp: timestamp
    vmName: vmName
    groupAdmins: groupAdmins
    groupUsers: groupUsers
  }
  dependsOn: [
    managementVm
    assignIdentity2StorageSMB
    assignIdentity2StorageContrib
    storageFileShare
  ]
}
