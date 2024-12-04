
targetScope = 'resourceGroup'

param AppGroupName string
param AppGroupType string
param CustomRdpProperty string
param DiskSku string
param DomainName string
param HostPoolStatus string
param HostPoolName string
param HostPoolOption string
param HostPoolType string
@secure()
param HostPoolWorkspaceName string
param Location string
param NumUsersPerHost int
param Tags object
param Timestamp string = utcNow('u')
param UseCustomImage bool
param StartVmOnConnect bool
param ComputeGalleryImageId string
param vmImage object
param VmPrefix string
param ValidationEnvironment bool
param VmSize string

var vmImagePub = vmImage.publisher
var vmOffer = vmImage.offer
var vmSKU = vmImage.sku
var vmGalleryItemId = '${vmImagePub}.${vmOffer}${vmSKU}'
var vmTemplateMS = '{"domain":"${DomainName}","galleryImageOffer":"${vmOffer}","galleryImagePublisher":"${vmImagePub}","galleryImageSKU":"${vmSKU}","imageType":"Gallery","customImageId":null,"namePrefix":"${VmPrefix}","osDiskType":"${DiskSku}","vmSize":{"id":"${VmSize}","cores":null,"ram":null},"galleryItemId":"${vmGalleryItemId}","hibernate":false,"diskSizeGB":0,"securityType":"TrustedLaunch","secureBoot":true,"vTPM":true}' 
var vmTemplateCompGal = '{"domain":"${DomainName}","galleryImageOffer":null,"galleryImagePublisher":null,"galleryImageSKU":null,"imageType":"CustomImage","imageUri":null,"customImageId":"${ComputeGalleryImageId}","namePrefix":"${VmPrefix}","osDiskType":"${DiskSku}","useManagedDisks":true,"vmSize":{"id":"${VmSize}","cores":null,"ram":null},"galleryItemId":null}' 
var vmTemplate = UseCustomImage ? vmTemplateCompGal : vmTemplateMS


// resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = if((HostPoolStatus != 'Existing') && (HostPoolOption != 'AltTenant')) {
  resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
name: HostPoolName
  location: Location
  tags: Tags[?'Microsoft.DesktopVirtualization/hostPools'] ?? {}
  properties: {
    hostPoolType: split(HostPoolType, ' ')[0]
    maxSessionLimit: NumUsersPerHost
    loadBalancerType: contains(HostPoolType, 'Pooled') ? split(HostPoolType, ' ')[1] :'Persistent'
    validationEnvironment: ValidationEnvironment
    registrationInfo: {
      expirationTime: dateTimeAdd(Timestamp, 'PT2H')
      registrationTokenOperation: 'Update'
    }
    preferredAppGroupType: AppGroupType == 'RemoteApp' ? 'RailApplications' : AppGroupType
    customRdpProperty: CustomRdpProperty
    personalDesktopAssignmentType: contains(HostPoolType, 'Personal') ? split(HostPoolType, ' ')[1] : null
    startVMOnConnect: StartVmOnConnect // https://docs.microsoft.com/en-us/azure/virtual-desktop/start-virtual-machine-connect
    vmTemplate: vmTemplate
  }
}
/*
resource hostPoolExisting 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' existing = if(HostPoolStatus == 'Existing') {
  name: HostPoolName
  scope: resourceGroup(subscription().subscriptionId, ResourceGroupHP)
}
*/

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = if((HostPoolStatus != 'Existing') && (HostPoolOption != 'AltTenant')) {
  name: AppGroupName
  location: Location
  tags: Tags[?'Microsoft.DesktopVirtualization/applicationGroups'] ?? {}
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: AppGroupType
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = if((HostPoolWorkspaceName != 'none') && (HostPoolOption != 'AltTenant')) {
  name: HostPoolWorkspaceName
  location: Location
  tags: Tags[?'Microsoft.DesktopVirtualization/workspaces'] ?? {}
  properties: {
    applicationGroupReferences: [
      appGroup.id
    ]
  }
  dependsOn: [
    hostPool
  ]
}

// output HostPoolRegistrationToken string = HostPoolStatus == 'Existing' ? hostPoolExisting.listRegistrationTokens()[0].token : hostPool.listRegistrationTokens()[0].token
output HostPoolRegistrationToken string = reference(hostPool.id).registrationInfo.token
