
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

@allowed([
  'AvailabilitySet'
  'AvailabilityZones'
  'None'
])
@description('Set the desired availability / SLA with a pooled host pool.  Choose "None" if deploying a personal host pool.')
param Availability string = 'None'

param ComputeGalleryRG string

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

param HPResourceGroup string
param HostPoolName string

@allowed([
  'Pooled DepthFirst'
  'Pooled BreadthFirst'
  'Personal Automatic'
  'Personal Direct'
])
@description('These options specify the host pool type and depending on the type provides the load balancing options and assignment types.')
param HostPoolType string = 'Pooled DepthFirst'

param HPVMsRG string
param WorkspaceName string
param Location string
param NumSessionHosts int
param NumUsersPerHost int
param Subnet string
param Tags object
param Timestamp string = utcNow('u')
param StartVmOnConnect bool
param OUPath string
param ComputeGalleryName string
param ImageName string
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


resource resourceGroupAVD 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: HPResourceGroup
  location: Location
}

resource resourceGroupVMs 'Microsoft.Resources/resourceGroups@2021-04-01' = if (HPResourceGroup != HPVMsRG) {
  name: HPVMsRG
  location: Location
}

resource computeGalleryImage 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
  name: '${ComputeGalleryName}/${ImageName}'
  scope: resourceGroup(ComputeGalleryRG)
}

module availabilitySets 'modules/availabilitySets.bicep' = if (PooledHostPool && Availability == 'AvailabilitySet') {
  name: 'AvailabilitySets_${Timestamp}'
  scope: resourceGroup(HPVMsRG) // Hosts Resource Group
  params: {
    AvailabilitySetCount: AvailabilitySetCount
    AvailabilitySetPrefix: AvailabilitySetPrefix
    Location: Location
    Tags: Tags
  }
  dependsOn: [
    resourceGroupAVD
    resourceGroupVMs
  ]
}

module hostPool 'modules/hostpool.bicep' = {
  name: 'HostPoolDeployment'
  scope: resourceGroup(HPResourceGroup)
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
    resourceGroupAVD
    resourceGroupVMs
  ]
}

@batchSize(1)
module virtualMachines 'modules/virtualmachines.bicep' = [for i in range(1, SessionHostBatchCount): {
  name: 'VirtualMachines_${i-1}_${guid(Timestamp)}'
  scope: resourceGroup(HPVMsRG)
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    Availability: Availability
    AvailabilitySetPrefix: AvailabilitySetPrefix
    ComputeGalleryImageId: computeGalleryImage.id
    DomainUser: DomainUser
    DomainPassword: DomainPassword
    DomainName: DomainName
    HostPoolRegistrationToken: hostPool.outputs.HostPoolRegistrationToken
    OUPath: OUPath
    Location: Location
    NumSessionHosts: NumSessionHosts
    Subnet: Subnet
    Tags: Tags
    Timestamp: Timestamp
    TrustedLaunch: computeGalleryImage.properties.features[0].value  //first array item is Security Type: Value
    VirtualNetwork: VirtualNetwork
    VirtualNetworkResourceGroup: VirtualNetworkResourceGroup
    VmIndexStart: VmIndexStart
    VmSize: VmSize
    VmUsername: VmUsername
    VmPassword: VmPassword
    VmPrefix: VmPrefix
  }
  dependsOn: [
    hostPool
  ]
}]


