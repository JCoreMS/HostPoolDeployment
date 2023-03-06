targetScope = 'subscription'

param _artifactsLocation string
@secure()
param _artifactsLocationSasToken string

param AppGroupName string

@allowed([
  'Desktop'
  'RailApplications'
])
param AppGroupType string

param AutomationAccountName string

@allowed([
  'AvailabilitySet'
  'AvailabilityZones'
  'None'
])
@description('Set the desired availability / SLA with a pooled host pool.  Choose "None" if deploying a personal host pool.')
param Availability string

param ComputeGalleryName string
param ComputeGallerySubId string
param ComputeGalleryRG string
param ComputeGalleryImage string

@description('If TRUE, Resource Group for Host Pool resources not required.')
param CrossTenantRegister bool

@secure()
param CrossTenantRegisterToken string

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

param ResourceGroupVMs string

@allowed([
  'Pooled DepthFirst'
  'Pooled BreadthFirst'
  'Personal Automatic'
  'Personal Direct'
])
@description('These options specify the host pool type and depending on the type provides the load balancing options and assignment types.')
param HostPoolType string

param WorkspaceName string
param Location string
param NewLogAnalyticsWS bool
param LogAnalyticsWorkspaceName string

@maxValue(730)
@minValue(30)
@description('The retention for the Log Analytics Workspace to setup the AVD Monitoring solution')
param LogAnalyticsWorkspaceRetention int = 30

@allowed([
  'Free'
  'Standard'
  'Premium'
  'PerNode'
  'PerGB2018'
  'Standalone'
  'CapacityReservation'
])
@description('The SKU for the Log Analytics Workspace to setup the AVD Monitoring solution')
param LogAnalyticsWorkspaceSku string = 'PerGB2018'
param LogAnalyticsSubId string
param LogAnalyticsRG string
param Monitoring bool
param NumSessionHosts int
param NumUsersPerHost int
param Subnet string
param Tags object
param Timestamp string = utcNow('u')
param UpdateWindows bool
param StartVmOnConnect bool
param OUPath string

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
param VmSize string = 'Standard_D4s_v4'

@description('The Local Administrator Username for the Session Hosts')
param VmUsername string

/*  BEGIN BATCHING SESSION HOSTS */
// The following variables are used to determine the batches to deploy any number of AVD session hosts.
var MaxResourcesPerTemplateDeployment = 79 // This is the max number of session hosts that can be deployed from the sessionHosts.bicep file in each batch / for loop. Math: (800 - <Number of Static Resources>) / <Number of Looped Resources> 
var DivisionValue = NumSessionHosts / MaxResourcesPerTemplateDeployment // This determines if any full batches are required.
var DivisionRemainderValue = NumSessionHosts % MaxResourcesPerTemplateDeployment // This determines if any partial batches are required.
var SessionHostBatchCount = DivisionRemainderValue > 0 ? DivisionValue + 1 : DivisionValue // This determines the total number of batches needed, whether full and / or partial.
/*  END BATCHING SESSION HOSTS */

/*  BEGIN AVAILABILITY SET COUNT */
// The following variables are used to determine the number of availability sets.
var MaxAvSetCount = 200 // This is the max number of session hosts that can be deployed in an availability set.
var DivisionAvSetValue = NumSessionHosts / MaxAvSetCount // This determines if any full availability sets are required.
var DivisionAvSetRemainderValue = NumSessionHosts % MaxAvSetCount // This determines if any partial availability sets are required.
var AvailabilitySetCount = DivisionAvSetRemainderValue > 0 ? DivisionAvSetValue + 1 : DivisionAvSetValue // This determines the total number of availability sets needed, whether full and / or partial.
/*  END AVAILABILITY SET COUNT */

var PooledHostPool = split(HostPoolType, ' ')[0] == 'Pooled' ? true : false
var AvailabilitySetPrefix = 'as-'
var DeployVMsTo = empty(ResourceGroupVMs) ? ResourceGroupHP : ResourceGroupVMs


resource resourceGroupHP 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ResourceGroupHP
  location: Location
}

resource resourceGroupVMs 'Microsoft.Resources/resourceGroups@2021-04-01' = if (!empty(ResourceGroupVMs)) {
  name: !empty(ResourceGroupVMs) ? ResourceGroupVMs : 'none'
  location: !empty(Location) ? Location : 'none'
}

resource computeGalleryImage 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
  name: '${ComputeGalleryName}/${ComputeGalleryImage}'
  scope: resourceGroup(ComputeGallerySubId, ComputeGalleryRG) //scope to alternate subscription
  //scope: resourceGroup(ComputeGalleryRG)
}

module automationAccount 'modules/automationAccount.bicep' = if(PooledHostPool) {
  name: 'linked_AutomationAccount_AVDHostPoolDeployment'
  scope: resourceGroup(ResourceGroupHP) // Management Resource Group
  params: {
    AutomationAccountName: AutomationAccountName
    Location: Location
  }
  dependsOn: [
    resourceGroupHP
  ]
}

module availabilitySets 'modules/availabilitySets.bicep' = if ((PooledHostPool && Availability == 'AvailabilitySet') && !CrossTenantRegister) {
  name: 'linked_AvailabilitySets_${Timestamp}'
  scope: resourceGroupHP
  params: {
    AvailabilitySetCount: AvailabilitySetCount
    AvailabilitySetPrefix: AvailabilitySetPrefix
    Location: Location
    Tags: Tags
  }
}

module hostPool 'modules/hostpool.bicep' = if (!CrossTenantRegister) {
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
    WorkspaceName: WorkspaceName
  }
  dependsOn: [
    resourceGroupHP
  ]
}

module logAnalyticsWorkspace 'modules/logAnalytics.bicep' = if (Monitoring) {
  scope: resourceGroup(LogAnalyticsSubId, LogAnalyticsRG)
  name: 'linked_logAnalyticsWorkspace'
  params: {
    LogAnalyticsWorkspaceName: LogAnalyticsWorkspaceName
    LogAnalyticsWorkspaceRetention: LogAnalyticsWorkspaceRetention
    LogAnalyticsWorkspaceSku: LogAnalyticsWorkspaceSku
    Location: Location
    NewLogAnalyticsWS: NewLogAnalyticsWS
    Tags: Tags
  }
}

// Monitoring Resources for AVD Insights
// This module deploys a Log Analytics Workspace with Windows Events & Windows Performance Counters plus diagnostic settings on the required resources 
module monitoring 'modules/monitoring.bicep' = if (Monitoring) {
  name: 'linked_Monitoring_Setup'
  scope: resourceGroup(ResourceGroupHP) // Management Resource Group
  params: {
    AutomationAccountName: AutomationAccountName
    HostPoolName: HostPoolName
    LogAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.logAnalyticsId
    PooledHostPool: PooledHostPool
    WorkspaceName: WorkspaceName
  }
  dependsOn: [
    logAnalyticsWorkspace
    resourceGroupHP
    hostPool
  ]
}

@batchSize(1)
module virtualMachines 'modules/virtualmachines.bicep' = [for i in range(1, SessionHostBatchCount): {
  name: 'linked_VirtualMachines_${i - 1}_${guid(Timestamp)}'
  scope: resourceGroup(DeployVMsTo)
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    Availability: Availability
    AvailabilitySetPrefix: AvailabilitySetPrefix
    ComputeGalleryImageId: '${computeGalleryImage.id}/versions/latest'
    ComputeGalleryProperties: computeGalleryImage.properties
    DomainUser: DomainUser
    DomainPassword: DomainPassword
    DomainName: DomainName
    HostPoolRegistrationToken: CrossTenantRegister ? CrossTenantRegisterToken : hostPool.outputs.HostPoolRegistrationToken
    OUPath: OUPath
    Location: Location
    LogAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.logAnalyticsId
    Monitoring: Monitoring
    NumSessionHosts: NumSessionHosts
    Subnet: Subnet
    Tags: Tags
    Timestamp: Timestamp
    UpdateWindows: UpdateWindows
    VirtualNetwork: VirtualNetwork
    VirtualNetworkResourceGroup: VirtualNetworkResourceGroup
    VmIndexStart: VmIndexStart
    VmSize: VmSize
    VmUsername: VmUsername
    VmPassword: VmPassword
    VmPrefix: VmPrefix
  }
  dependsOn: (!CrossTenantRegister) ? [
    hostPool
    monitoring
  ] : []
}]
