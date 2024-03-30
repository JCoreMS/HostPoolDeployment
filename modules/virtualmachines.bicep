param AgentPackageLocation string
param ComputeGalleryImageId string
param ComputeGalleryProperties object
param DedicatedHostResId string
param DedicatedHostTagName string
@secure()
param DomainName string
param DomainUser string
@secure()
param DomainPassword string
param HostPoolName string
param HostPoolRegistrationToken string
param Location string
param LogAnalyticsWorkspaceId string
param NumSessionHosts int
@description('Market Place OS image.')
param MarketPlaceGalleryWindows object
param PostDeployEndpoint string
param PostDeployScript string
param PostDeployOption bool
param PostDeployOptVDOT bool
param Restart bool
param Subnet string
param Tags object
param Timestamp string
param UpdateWindows bool
@description('Optional. Set to deploy image from Azure Compute Gallery. (Default: false)')
param UseCustomImage bool
param UserIdentityResId string
param UserIdentityObjId string
param OUPath string
param VirtualNetwork string
param VirtualNetworkResourceGroup string
param VmIndexStart int
param VmPrefix string
param VmSize string
param VmUsername string
@secure()
param VmPassword string
param Zones array


var SharedImageSecType = contains(ComputeGalleryProperties, 'features') ? filter(ComputeGalleryProperties.features[0], feature => feature.name == 'SecurityType').value : 'Standard'
var SecurityType = SharedImageSecType =='TrustedLaunchSupported' ? 'TrustedLaunch' : SharedImageSecType
var securityProfileJson = {
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: SecurityType
}

var imageToUse = UseCustomImage ? { id: ComputeGalleryImageId } : MarketPlaceGalleryWindows

var DedicatedHostName = split(DedicatedHostResId, '/')[10]
var vmTagDH = !empty(DedicatedHostTagName) ? { DedicatedHostTagName : DedicatedHostName} : {}
var vmTags = !empty(DedicatedHostTagName) ? union(vmTagDH, Tags) : Tags

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = [for i in range(0, NumSessionHosts): {
  name: 'nic-${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}'
  location: Location
  tags: contains(Tags, 'Microsoft.Network/networkInterfaces') ? Tags['Microsoft.Network/networkInterfaces'] : {}
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId(subscription().subscriptionId, VirtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', VirtualNetwork, Subnet)
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: true
    enableIPForwarding: false
  }
}]

// No OS Profile for Dedicated Host
resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' = [for i in range(0, NumSessionHosts): {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}'
  location: Location
  tags: contains(vmTags, 'Microsoft.Compute/virtualMachines') ? vmTags['Microsoft.Compute/virtualMachines'] : {}
  identity: PostDeployOption ? {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${UserIdentityResId}': {}
    }
  } : {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: VmSize
    }
    storageProfile: {
      imageReference: imageToUse
      osDisk: {
        name: 'osDisk-${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}'
        osType: 'Windows'
        createOption: 'FromImage'
        caching: 'ReadOnly'
        deleteOption: 'Delete'
      }
      dataDisks: []
    }
    osProfile: {
      computerName: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}'
      adminUsername: VmUsername
      adminPassword: VmPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
      secrets: []
      allowExtensionOperations: true
    }
    host: !empty(DedicatedHostResId) ? {
      id: DedicatedHostResId
    } : null
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', 'nic-${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}')
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: ((SecurityType == 'TrustedLaunch') ? securityProfileJson : null )
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    licenseType: 'Windows_Client'
  }
  zones: !empty(Zones) ? Zones : null
  dependsOn: [
    networkInterface
  ]
}]

/* resource extension_MicrosoftMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, NumSessionHosts): {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}/MicrosoftMonitoringAgent'
  location: Location
  tags: contains(Tags, 'Microsoft.Compute/virtualMachines/extensions') ? Tags['Microsoft.Compute/virtualMachines/extensions'] : {}
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: reference(LogAnalyticsWorkspaceId, '2015-03-20').customerId
    }
    protectedSettings: {
      workspaceKey: listKeys(LogAnalyticsWorkspaceId, '2015-03-20').primarySharedKey
    }
  }
  dependsOn: [
    virtualMachine
  ]
}] */
resource extension_AzureMonitorWindowsAgent 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, NumSessionHosts): {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}/AzureMonitorWindowsAgent'
  location: Location
  tags: contains(Tags, 'Microsoft.Compute/virtualMachines/extensions') ? Tags['Microsoft.Compute/virtualMachines/extensions'] : {}
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
  dependsOn: [
    virtualMachine
  ]
}]

resource extension_JsonADDomainExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, NumSessionHosts): {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}/JsonADDomainExtension'
  location: Location
  tags: contains(Tags, 'Microsoft.Compute/virtualMachines/extensions') ? Tags['Microsoft.Compute/virtualMachines/extensions'] : {}
  properties: {
    forceUpdateTag: Timestamp
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: DomainName
      User: DomainUser
      Restart: 'true'
      Options: '3'
      OUPath: OUPath
    }
    protectedSettings: {
      Password: DomainPassword
    }
  }
  dependsOn: [
    extension_AzureMonitorWindowsAgent
  ]
}]


resource extension_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, NumSessionHosts): if(PostDeployOption) {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}/CustomScriptExtension'
  location: Location
  tags: contains(Tags, 'Microsoft.Compute/virtualMachines/extensions') ? Tags['Microsoft.Compute/virtualMachines/extensions'] : {}
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${PostDeployEndpoint}/${PostDeployScript}'
      ]
      timestamp: Timestamp
    }
    protectedSettings: {
      managedIdentity: { objectId: UserIdentityObjId }
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ${PostDeployScript} -WindowsUpdate ${UpdateWindows} -Restart ${Restart} -VDOT ${PostDeployOptVDOT}'
    }
  }
  dependsOn: [
    extension_JsonADDomainExtension
  ]
}]


// Add session hosts to Host Pool.
resource addToHostPool 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, NumSessionHosts): {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}/HostPoolRegistration'
  location: Location
  tags: contains(Tags, 'Microsoft.Compute/virtualMachines/extensions') ? Tags['Microsoft.Compute/virtualMachines/extensions'] : {}
  properties: {
    publisher: 'Microsoft.PowerShell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: AgentPackageLocation
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: HostPoolName
        registrationInfoToken: HostPoolRegistrationToken
        aadJoin: false
      }
    }
  }
  dependsOn: PostDeployOption ? [
    extension_JsonADDomainExtension
  ] : [
    extension_CustomScriptExtension
  ]
}]

