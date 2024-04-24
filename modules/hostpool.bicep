
targetScope = 'resourceGroup'

param AppGroupName string
param AppGroupType string
param CustomRdpProperty string
param DiskSku string
param DomainName string
param HostPoolStatus string
param HostPoolName string
param HostPoolType string
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

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-10-14-preview' = if(HostPoolStatus != 'Existing') {
  name: HostPoolName
  location: Location
  tags: contains(Tags, 'Microsoft.DesktopVirtualization/hostPools') ? Tags['Microsoft.DesktopVirtualization/hostPools'] : {}
  properties: {
    hostPoolType: split(HostPoolType, ' ')[0]
    maxSessionLimit: NumUsersPerHost
    loadBalancerType: contains(HostPoolType, 'Pooled') ? split(HostPoolType, ' ')[1] :'Persistent'
    validationEnvironment: ValidationEnvironment
    registrationInfo: {
      expirationTime: dateTimeAdd(Timestamp, 'PT2H')
      registrationTokenOperation: 'Update'
    }
    preferredAppGroupType: AppGroupType
    customRdpProperty: CustomRdpProperty
    personalDesktopAssignmentType: contains(HostPoolType, 'Personal') ? split(HostPoolType, ' ')[1] : null
    startVMOnConnect: StartVmOnConnect // https://docs.microsoft.com/en-us/azure/virtual-desktop/start-virtual-machine-connect
    vmTemplate: vmTemplate
  }
}

resource hostPoolExisting 'Microsoft.DesktopVirtualization/hostPools@2022-10-14-preview' = if(HostPoolStatus == 'Existing') {
  name: HostPoolName
  location: Location
  tags: contains(Tags, 'Microsoft.DesktopVirtualization/hostPools') ? Tags['Microsoft.DesktopVirtualization/hostPools'] : {}
}


resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2022-10-14-preview' = if(HostPoolStatus != 'Existing') {
  name: AppGroupName
  location: Location
  tags: contains(Tags, 'Microsoft.DesktopVirtualization/applicationGroups') ? Tags['Microsoft.DesktopVirtualization/applicationGroups'] : {}
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'Desktop'
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2022-10-14-preview' = if(HostPoolWorkspaceName != 'none') {
  name: HostPoolWorkspaceName
  location: Location
  tags: contains(Tags, 'Microsoft.DesktopVirtualization/workspaces') ? Tags['Microsoft.DesktopVirtualization/workspaces'] : {}
  properties: {
    applicationGroupReferences: [
      appGroup.id
    ]
  }
  dependsOn: [
    hostPool
  ]
}

// output HostPoolRegistrationToken string = hostPool.properties.registrationInfo.token
output HostPoolRegistrationToken string = hostPoolExisting != 'Existing' ? hostPool.properties.registrationInfo.token : hostPoolExisting.properties.registrationInfo.token
output ComputeImageGalleryID string = ComputeGalleryImageId
