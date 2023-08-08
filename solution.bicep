targetScope = 'subscription'

param AppGroupName string

@allowed([
  'Desktop'
  'RailApplications'
])
param AppGroupType string

@allowed([
  'win10_21h2'
  'win10_21h2_office'
  'win10_22h2_g2'
  'win10_22h2_office_g2'
  'win11_21h2'
  'win11_21h2_office'
  'win11_22h2'
  'win11_22h2_office'
])
@description('Optional. AVD OS image SKU. (Default: win11-21h2)')
param avdOsImage string = 'win11_22h2'

param ComputeGalleryName string = ''
param ComputeGallerySubId string = ''
param ComputeGalleryRG string = ''
param ComputeGalleryImage string = ''

param CustomRdpProperty string

@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
@description('The storage SKU for the AVD session host disks.  Production deployments should use Premium_LRS.')
param DiskSku string = 'Standard_LRS'

param DomainName string
param DomainUser string

@secure()
param DomainPassword string

param ResourceGroupHP string
param HostPoolName string
param HostPoolWorkspaceName string = 'none'

param ResourceGroupVMs string = ''

@allowed([
  'Pooled'
  'Personal'
])
@description('These options specify the host pool type and depending on the type provides the load balancing options and assignment types.')
param HostPoolKind string

@allowed([
  'DepthFirst'
  'BreadthFirst'
  'Automatic'
  'Direct'
])
@description('These options specify the host pool type and depending on the type provides the load balancing options and assignment types.')
param HostPoolLBType string

param KeyVaultDomainOption bool
param KeyVaultLocalOption bool
param KeyVaultDomain object = {}
param KeyVaultLocal object = {}
param KeyVaultDomSecret string = ''
param KeyVaultLocSecret string = ''

param Location string = deployment().location
param LogAnalyticsWorkspaceName string = ''
param LogAnalyticsSubId string
param LogAnalyticsRG string
param NumSessionHosts int
param NumUsersPerHost int
param PostDeployEndpoint string = ''
param PostDeployScript string
param PostDeployStorName string
param PostDeployStorRG string
param Restart bool = true
param Subnet string
param Tags object = {}
param Timestamp string = utcNow()
param UpdateWindows bool
param UserIdentityName string
param StartVmOnConnect bool
param OUPath string

@description('Optional. Set to deploy image from Azure Compute Gallery. (Default: false)')
param useSharedImage bool = false

@maxValue(99)
param VmIndexStart int

@maxLength(13)
param VmPrefix string

@description('The value determines whether the hostpool should receive early AVD updates for testing.')
param ValidationEnvironment bool = false

@description('Virtual network for the AVD sessions hosts')
param VirtualNetwork string

@description('Virtual network resource group for the AVD sessions hosts')
param VirtualNetworkResourceGroup string

@secure()
@description('Local administrator password for the AVD session hosts')
param VmPassword string

@description('The VM SKU for the AVD session hosts.')
param VmSize string

@description('The Local Administrator Username for the Session Hosts')
param VmUsername string

/*  BEGIN BATCHING SESSION HOSTS */
// The following variables are used to determine the batches to deploy any number of AVD session hosts.
var MaxResourcesPerTemplateDeployment = 79 // This is the max number of session hosts that can be deployed from the sessionHosts.bicep file in each batch / for loop. Math: (800 - <Number of Static Resources>) / <Number of Looped Resources> 
var DivisionValue = NumSessionHosts / MaxResourcesPerTemplateDeployment // This determines if any full batches are required.
var DivisionRemainderValue = NumSessionHosts % MaxResourcesPerTemplateDeployment // This determines if any partial batches are required.
var SessionHostBatchCount = DivisionRemainderValue > 0 ? DivisionValue + 1 : DivisionValue // This determines the total number of batches needed, whether full and / or partial.
/*  END BATCHING SESSION HOSTS */

var varAvdAgentPackageLocation = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration_09-08-2022.zip'
var HostPoolType = '${HostPoolKind} ${HostPoolLBType}'
var DeployVMsTo = empty(ResourceGroupVMs) ? ResourceGroupHP : ResourceGroupVMs

var varKvDomSubId = KeyVaultDomainOption ? split(KeyVaultDomain.id, '/')[2] : 'none'
var varKvLocSubId = KeyVaultLocalOption ? split(KeyVaultLocal.id, '/')[2] : 'none'
var varKvDomRg = KeyVaultDomainOption ? split(KeyVaultDomain.id, '/')[4] : 'none'
var varKvLocRg = KeyVaultLocalOption ? split(KeyVaultLocal.id, '/')[4] : 'none'

var RoleAssignments = {
  BlobDataRead: {
    Name: 'Blob-Data-Reader'
    GUID: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Read and list Azure Storage containers and blobs.
  }
  ARMRead: {
    Name: 'ARM-Reader'
    GUID: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' //View all resources, but does not allow you to make any changes
  }
}

var varMarketPlaceGalleryWindows = {
  win10_22h2_g2: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'windows-10'
      sku: 'win10-22h2-avd-g2'
      version: 'latest'
  }
  win10_22h2_office_g2: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'office-365'
      sku: 'win10-21h2-avd-m365-g2'
      version: 'latest'
  }
  win11_21h2: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'Windows-11'
      sku: 'win11-21h2-avd'
      version: 'latest'
  }
  win11_21h2_office: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'office-365'
      sku: 'win11-21h2-avd-m365'
      version: 'latest'
  }
  win11_22h2: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'Windows-11'
      sku: 'win11-22h2-avd'
      version: 'latest'
  }
  win11_22h2_office: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'office-365'
      sku: 'win11-22h2-avd-m365'
      version: 'latest'
  }
  winServer_2022_Datacenter: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter'
      version: 'latest'
  }
  winServer_2022_datacenter_core: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-core'
      version: 'latest'
  }
  winServer_2022_datacenter_azure_edition_core: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition-core'
      version: 'latest'
  }
  winServer_2022_Datacenter_core_smalldisk_g2: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-core-smalldisk-g2'
      version: 'latest'
  }
}

resource resourceGroupHP 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ResourceGroupHP
  location: Location
}

resource kvDomain 'Microsoft.KeyVault/vaults@2022-11-01' existing = if(KeyVaultDomainOption) {
  name: KeyVaultDomain.Name
  scope: resourceGroup(varKvDomSubId, varKvDomRg)
}

resource kvLocal 'Microsoft.KeyVault/vaults@2022-11-01' existing = if(KeyVaultLocalOption) {
  name: KeyVaultLocal.Name
  scope: resourceGroup(varKvLocSubId, varKvLocRg)
}

resource resourceGroupVMs 'Microsoft.Resources/resourceGroups@2021-04-01' = if (!empty(ResourceGroupVMs)) {
  name: !empty(ResourceGroupVMs) ? ResourceGroupVMs : 'none'
  location: !empty(Location) ? Location : 'none'
}

resource computeGalleryImage 'Microsoft.Compute/galleries/images@2022-03-03' existing = if(!empty(ComputeGalleryName)) {
  name: '${ComputeGalleryName}/${ComputeGalleryImage}'
  scope: resourceGroup(ComputeGallerySubId, ComputeGalleryRG) //scope to alternate subscription
}

module userIdentity 'modules/userIdentity.bicep' = {
  scope: resourceGroup(ResourceGroupHP)
  name: 'linked_UserIdentityCreateAssign'
  params: {
    Location: Location
    PostDeployStorRG: PostDeployStorRG
    PostDeployStorName: PostDeployStorName
    RoleAssignments: RoleAssignments
    UserIdentityName: UserIdentityName
  }
}

module logAnalyticsWorkspace 'modules/logAnalytics.bicep' = {
  scope: resourceGroup(LogAnalyticsSubId, LogAnalyticsRG)
  name: 'linked_logAnalyticsWorkspace'
  params: {
    LogAnalyticsWorkspaceName: LogAnalyticsWorkspaceName
  }
}

module hostPool 'modules/hostpool.bicep' = {
  name: 'linked_HostPoolDeployment'
  scope: resourceGroup(ResourceGroupHP)
  params: {
    AppGroupName: AppGroupName
    AppGroupType: AppGroupType
    ComputeGalleryImageId: computeGalleryImage.id
    CustomRdpProperty: CustomRdpProperty
    DiskSku: DiskSku
    DomainName: DomainName
    HostPoolName: HostPoolName
    HostPoolType: HostPoolType
    Location: Location
    NumUsersPerHost: NumUsersPerHost
    StartVmOnConnect: StartVmOnConnect
    Tags: Tags
    ValidationEnvironment: ValidationEnvironment
    VmPrefix: VmPrefix
    VmSize: VmSize
    HostPoolWorkspaceName: HostPoolWorkspaceName
  }
  dependsOn: [
    resourceGroupHP
  ]
}

// Monitoring Resources for AVD Insights
// This module configures Log Analytics Workspace with Windows Events & Windows Performance Counters plus diagnostic settings on the required resources 
module monitoring 'modules/monitoring.bicep' = {
  name: 'linked_Monitoring_Setup'
  scope: resourceGroup(ResourceGroupHP) // Management Resource Group
  params: {
    HostPoolName: HostPoolName
    LogAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.logAnalyticsId
    HostPoolWorkspaceName: HostPoolWorkspaceName
  }
  dependsOn: [
    logAnalyticsWorkspace
    resourceGroupHP
    hostPool
  ]
}

@batchSize(1)
module virtualMachines 'modules/virtualmachines.bicep' = [for i in range(1, SessionHostBatchCount): {
  name: 'linked_VirtualMachines_batch_${i - 1}'
  scope: resourceGroup(DeployVMsTo)
  params: {
    AgentPackageLocation: varAvdAgentPackageLocation
    ComputeGalleryImageId: useSharedImage ? '${computeGalleryImage.id}/versions/latest' : 'none'
    ComputeGalleryProperties: useSharedImage ? computeGalleryImage.properties : {}
    DomainUser: DomainUser
    DomainPassword: KeyVaultDomainOption ? kvDomain.getSecret(KeyVaultDomSecret) : DomainPassword
    DomainName: DomainName
    HostPoolName: HostPoolName
    HostPoolRegistrationToken: hostPool.outputs.HostPoolRegistrationToken
    Location: Location
    LogAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.logAnalyticsId
    NumSessionHosts: NumSessionHosts
    MarketPlaceGalleryWindows: useSharedImage ? {} : varMarketPlaceGalleryWindows[avdOsImage]
    OUPath: OUPath
    PostDeployEndpoint: PostDeployEndpoint
    PostDeployScript: PostDeployScript
    Restart: Restart
    Subnet: Subnet
    Tags: Tags
    Timestamp: Timestamp
    UpdateWindows: UpdateWindows
    useSharedImage: useSharedImage
    UserIdentityResId: userIdentity.outputs.userIdentityResId
    UserIdentityObjId: userIdentity.outputs.userIdentityObjId
    VirtualNetwork: VirtualNetwork
    VirtualNetworkResourceGroup: VirtualNetworkResourceGroup
    VmIndexStart: VmIndexStart
    VmSize: VmSize
    VmUsername: VmUsername
    VmPassword: KeyVaultLocalOption ? kvLocal.getSecret(KeyVaultLocSecret) : VmPassword
    VmPrefix: VmPrefix
  }
  dependsOn: [
    monitoring
    userIdentity
  ]
}]
