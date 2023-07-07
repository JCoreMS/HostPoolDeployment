
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
param marketPlaceGalleryWindows object
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
var SecurityFeature = contains(ComputeGalleryProperties, 'features') ? filter(ComputeGalleryProperties.features, feature => feature.name == 'SecurityType')[0].value : 'Standard'
var storageProfile = {
  imageReference: useSharedImage ? {
    id: ComputeGalleryImageId
  } : marketPlaceGalleryWindows
  osDisk: {
    name: 'osDisk-${VmPrefix}'
    osType: 'Windows'
    createOption: 'FromImage'
    caching: 'ReadOnly'
    deleteOption: 'Delete'
  }
  dataDisks: []
}




output RegistrationToken string = HostPoolRegistrationToken
output HyperVGen string = HyperVGen
output Architecture string = Architecture
output ComputeGalProp object = ComputeGalleryProperties
output SecurityFeatureValue string = SecurityFeature
output useSharedImage bool = useSharedImage
output ComputeGalleryImageId string = ComputeGalleryImageId
output marketPlaceGalleryWindows object = marketPlaceGalleryWindows
output storageProfile object = storageProfile
