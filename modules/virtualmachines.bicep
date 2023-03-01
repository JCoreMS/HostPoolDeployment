
param _artifactsLocation string
@secure()
param _artifactsLocationSasToken string

param Availability string
param AvailabilitySetPrefix string
param ComputeGalleryImageId string
param ComputeGalleryProperties object
@secure()
param DomainName string
param DomainUser string
@secure()
param DomainPassword string
param HostPoolRegistrationToken string
param Location string
param LogAnalyticsWorkspaceId string
param Monitoring bool
param NumSessionHosts int
param Subnet string
param Tags object
param Timestamp string
param UpdateWindows bool
param UpdateApps bool
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
var SecurityFeature = contains(ComputeGalleryProperties, 'features') ? filter(ComputeGalleryProperties.features, feature => feature.name == 'SecurityType')[0].value : 'Standard'


resource networkInterface 'Microsoft.Network/networkInterfaces@2020-05-01' = [for i in range(0, NumSessionHosts): {
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

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, NumSessionHosts): {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}'
  location: Location
  tags: Tags
  zones: Availability == 'AvailabilityZones' ? [
    string((i % 3) + 1)
  ] : null
  properties: {
    availabilitySet: Availability == 'AvailabilitySet' ? {
      id: resourceId('Microsoft.Compute/availabilitySets', '${AvailabilitySetPrefix}-${(i + VmIndexStart) / 200}')
    } : null
    hardwareProfile: {
      vmSize: VmSize
    }
    storageProfile: {
      imageReference: {
        id: ComputeGalleryImageId
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
    securityProfile: {
      uefiSettings: SecurityFeature == 'Standard' ? null : {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: SecurityFeature == 'Standard' ? null : SecurityFeature
    }
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

resource extension_MicrosoftMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, NumSessionHosts): if(Monitoring) {
  name: '${VmPrefix}${padLeft((i + VmIndexStart), 3, '0')}/MicrosoftMonitoringAgent'
  location: Location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: Monitoring ? reference(LogAnalyticsWorkspaceId, '2015-03-20').customerId : null
    }
    protectedSettings: {
      workspaceKey: Monitoring ? listKeys(LogAnalyticsWorkspaceId, '2015-03-20').primarySharedKey : null
    }
  }
  dependsOn: [
    virtualMachine
  ]
}]

resource extension_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, NumSessionHosts): {
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
        '${_artifactsLocation}Register-HostPool-PostConfig.ps1${_artifactsLocationSasToken}'
      ]
      timestamp: Timestamp
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Register-HostPool-PostConfig.ps1 -HostPoolRegistration ${HostPoolRegistrationToken} -AllAppsUpdate ${UpdateApps} -WindowsUpdate ${UpdateWindows}'
    }
  }
  dependsOn: [
    virtualMachine
    extension_MicrosoftMonitoringAgent
  ]
}]


resource extension_JsonADDomainExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, NumSessionHosts): {
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
    virtualMachine
    extension_CustomScriptExtension
    extension_MicrosoftMonitoringAgent
  ]
}]


output RegistrationToken string = HostPoolRegistrationToken
output HyperVGen string = HyperVGen
output Architecture string = Architecture
output ComputeGalProp object = ComputeGalleryProperties
output SecurityFeatureValue string = SecurityFeature

