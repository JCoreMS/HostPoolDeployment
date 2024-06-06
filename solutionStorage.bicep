targetScope = 'resourceGroup'

param domainJoinUserName string

@secure()
param domainJoinUserPassword string

param groupAdmins string

param groupUsers string

@description('Expiration time of the key')
param keyExpiration int = dateTimeToEpoch(dateTimeAdd(utcNow(), 'P1Y'))

param keyVaultName string

param location string = resourceGroup().location

param managedIdentityName string

param ouPathStorage string

param ouPathVm string

param privateDNSZoneId string

param storageAcctName string

param storageFileShareName string

param storageResourceGroup string

param storageShareSize int

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param storageSKU string

param subnetId string

param tags object

param timestamp string = utcNow()

param vmName string
param vmAdminUsername string
@secure()
param vmAdminPassword string

var domainJoinFQDN = split(domainJoinUserName, '@')[1]

var scriptLocation = 'https://raw.githubusercontent.com/JCoreMS/HostPoolDeployment/master/scripts' // URL with NO trailing slash
var smbSettings = storageSKU == 'Premium_LRS' || storageSKU == 'Premium_ZRS'
  ? {
      authenticationMethods: 'NTLMv2;Kerberos'
      channelEncryption: 'AES-256-GCM;AES-128-GCM;AES-128-CCM'
      kerberosTicketEncryption: 'AES-256;RC4-HMAC'
      mulitchannel: { enabled: true }
      versions: 'SMB3.0;SMB3.1.1'
    }
  : {
      authenticationMethods: 'NTLMv2;Kerberos'
      channelEncryption: 'AES-256-GCM;AES-128-GCM;AES-128-CCM'
      kerberosTicketEncryption: 'AES-256;RC4-HMAC'
      versions: 'SMB3.0;SMB3.1.1'
    }
var storageSetupScript = 'domainJoinStorageAcct.ps1'
var tenantId = subscription().tenantId


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
}

// Create Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAcctName
  location: location
  tags: tags
  sku: {
    name: storageSKU
  }
  kind: 'StorageV2'
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
    keyVaultKey
  ]
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
  dependsOn: [
    storageAccount
  ]
}

// Assign Managed Identity to Storage Account
resource assignIdentity2StorageRead 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, 'assignIdentity2StorageRead')
  scope: storageAccount
  properties: {
    description: 'Provides User Identity ${identityStorageSetup.name} access to Key Vault ${keyVault.name}'
    principalId: identityStorageSetup.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'c12c1c16-33a1-487b-954d-41c89c60f349'
    ) // Reader and Data Access (Storage)
  }
  dependsOn: [
    storageAccount
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


// Create Management Virtual Machine and domain join storage
//     System Managed Identity to access storage

module managementVm './modules/storage/managementVm.bicep' = {
  name: 'linked_managementVm'
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



module managementVmScript './modules/storage/managementVmScript.bicep' = {
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
    assignIdentity2StorageRead
    storageFileShare
  ]
}
