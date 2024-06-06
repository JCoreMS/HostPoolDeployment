targetScope = 'resourceGroup'

param assignedIdentityId string
param domainJoinFQDN string
param domainJoinOUPath string
param domainJoinUserName string
@secure()
param domainJoinUserPassword string
param location string = resourceGroup().location

param subnetId string
param tags object
param timestamp string = utcNow('u')
param vmName string
param vmAdminUsername string
@secure()
param vmAdminPassword string

var securityProfileJson = {
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: 'TrustedLaunch'
}

var imageToUse = {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'Windows-11'
  sku: 'win11-23h2-ent'
  version: 'latest'
}

var VmSize = 'Standard_D2s_v4'

resource networkInterfaceMgmtVM 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: 'nic-${vmName}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: true
    enableIPForwarding: false
  }
}

resource virtualMachineStorMgmt 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${assignedIdentityId}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: VmSize
    }
    storageProfile: {
      imageReference: imageToUse
      osDisk: {
        name: '${vmName}_osdisk'
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
      }
      dataDisks: []
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceMgmtVM.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: securityProfileJson
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    licenseType: 'Windows_Client'
  }
}



resource extension_JsonADDomainExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: 'JsonADDomainExtension'
  parent: virtualMachineStorMgmt
  location: location
  tags: tags
  properties: {
    forceUpdateTag: timestamp
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: domainJoinFQDN
      User: domainJoinUserName
      Restart: 'true'
      Options: '3'
      OUPath: domainJoinOUPath
    }
    protectedSettings: {
      Password: domainJoinUserPassword
    }
  }
}
