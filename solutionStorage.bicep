param domainJoinUserName string

@secure()
param domainJoinUserPassword string

param groupAdmins string

param groupUsers string

param kerberosEncryptionType string = 'AES256'

@description('Expiration time of the key')
param keyExpiration int = dateTimeToEpoch(dateTimeAdd(utcNow(), 'P1Y'))

param keyVaultName string

param location string = resourceGroup().location

param managedIdentityName string

param ouPath string

param privateDNSZoneId string

param smbSettings object

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

param tenantId string

param timestamp string = utcNow()

param vmName string
param vmAdminUsername string
@secure()
param vmAdminPassword string

var domainJoinFQDN = split(domainJoinUserName, '@')[1]
var scriptLocation = 'https://raw.githubusercontent.com/JCoreMS/HostPoolDeployment/master/scripts'  // URL with NO trailing slash
var storageSetupScript = 'domainJoinStorageAcct.ps1'
var smbSettingsInitial = {
  versions: 'SMB2.1;SMB3.0;SMB3.1.1'
  authenticationMethods: 'Kerberos;NTLMv2'
  kerberosTicketEncryption: 'RC4-HMAC;AES-256'
  channelEncryption: 'AES-128-CCM;AES-128-GCM;AES-256-GCM'
}

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
          action: {type: 'rotate'}
          trigger: {timeBeforeExpiry: 'P90D'}
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
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'e147488a-f6f5-4113-8e2d-b22465e65bf6') // Key Vault Crypto Service Encryption User Role
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
    allowSharedKeyAccess: false
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
        keyvaulturi:  endsWith(keyVault.properties.vaultUri,'/') ? substring(keyVault.properties.vaultUri,0,length(keyVault.properties.vaultUri)-1) : keyVault.properties.vaultUri
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
      smb: smbSettingsInitial
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
  name: 'managementVm'
  params: {
    domainJoinFQDN: domainJoinFQDN
    domainJoinOUPath: ouPath
    domainJoinUserName: domainJoinUserName
    domainJoinUserPassword: domainJoinUserPassword
    location: location
    subnetId: subnetId
    vmName: vmName
    tags: tags
    vmAdminPassword: vmAdminPassword
    vmAdminUsername: vmAdminUsername
  }
}

module roleAssignments './modules/storage/storageRoleAssignments.bicep' = {
  name: 'roleAssignments'
  scope: resourceGroup(storageResourceGroup)
  params: {
    keyVaultName: keyVaultName
    managementVmPrincipalId: managementVm.outputs.vmPrincipalId
    storageAccountId: storageAccount.id
    vmName: vmName
  }
}


module managementVmScript './modules/storage/managementVmScript.bicep' = {
  name: 'managementVMscript'
  params: {
    domainJoinOUPath: ouPath
    domainJoinUserName: domainJoinUserName
    domainJoinUserPassword: domainJoinUserPassword
    location: location
    scriptLocation: scriptLocation
    storageSetupScript: storageSetupScript
    storageSetupId: identityStorageSetup.id
    storageAccountName: storageAcctName
    storageFileShareName: storageFileShareName
    storageResourceGroup: storageResourceGroup
    tags: tags
    timestamp: timestamp
    vmName: vmName
    groupAdmins: groupAdmins
    groupUsers: groupUsers
    kerberosEncryptionType: kerberosEncryptionType
  }
  dependsOn: [
    managementVm
    roleAssignments
  ]
}


