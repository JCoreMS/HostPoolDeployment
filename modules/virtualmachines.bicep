param AgentPackageLocation string
param ComputeGalleryImageId string
param ComputeGalleryProperties object
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
param Restart bool
param Subnet string
param Tags object
param Timestamp string
param UpdateWindows bool
@description('Optional. Set to deploy image from Azure Compute Gallery. (Default: false)')
param useSharedImage bool
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

var HyperVGen = ComputeGalleryProperties.hyperVGeneration
var Architecture = ComputeGalleryProperties.architecture
var SecurityType = contains(ComputeGalleryProperties, 'features') ? filter(ComputeGalleryProperties.features, feature => feature.name == 'SecurityType')[0].value : 'TrustedLaunch'
var securityProfileJson = {
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: SecurityType
}
var imageToUse = useSharedImage ? { id: ComputeGalleryImageId } : MarketPlaceGalleryWindows

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = [for i in range(0, NumSessionHosts): {
  name: 'nic-${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}'
  location: Location
  tags: Tags
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

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' = [for i in range(0, NumSessionHosts): {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}'
  location: Location
  tags: Tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${UserIdentityResId}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: VmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-10'
        sku: 'win10-22h2-avd-g2'
        version: 'latest'
      }
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
    securityProfile: ((SecurityType == 'TrustedLaunch') ? securityProfileJson : null)
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    licenseType: 'Windows_Client'
  }
  dependsOn: [
    networkInterface
  ]
}]

resource extension_MicrosoftMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, NumSessionHosts): {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}/MicrosoftMonitoringAgent'
  location: Location
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
}]

resource extension_JsonADDomainExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, NumSessionHosts): {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}/JsonADDomainExtension'
  location: Location
  tags: Tags
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
    extension_MicrosoftMonitoringAgent
  ]
}]

// Add session hosts to Host Pool.
resource addToHostPool 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, NumSessionHosts): {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}/HostPoolRegistration'
  location: Location
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
  dependsOn: [
    extension_JsonADDomainExtension
  ]
}]

resource extension_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, NumSessionHosts): if (!empty(PostDeployEndpoint)) {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}/CustomScriptExtension'
  location: Location
  tags: Tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${PostDeployEndpoint}${PostDeployScript}'
      ]
      timestamp: Timestamp
    }
    protectedSettings: {
      managedIdentity: { objectId: UserIdentityObjId }
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ${PostDeployScript} -WindowsUpdate ${UpdateWindows} -Restart ${Restart}'
    }
  }
  dependsOn: [
    addToHostPool
  ]
}]

output RegistrationToken string = HostPoolRegistrationToken
output HyperVGen string = HyperVGen
output Architecture string = Architecture
output ComputeGalProp object = ComputeGalleryProperties
output useSharedImage bool = useSharedImage
output ComputeGalleryImageId string = ComputeGalleryImageId
output marketPlaceGalleryWindows object = MarketPlaceGalleryWindows
