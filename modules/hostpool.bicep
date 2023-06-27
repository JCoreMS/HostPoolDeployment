
targetScope = 'resourceGroup'

param AppGroupName string
param AppGroupType string
param CustomRdpProperty string
param DiskSku string
param DomainName string
param HostPoolName string
param HostPoolType string
param WorkspaceName string
param Location string
param NumUsersPerHost int
param Tags object
param Timestamp string = utcNow('u')
param StartVmOnConnect bool
param ComputeGalleryImageId string
param VmPrefix string
param ValidationEnvironment bool
param VmSize string




resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-04-01-preview' = {
  name: HostPoolName
  location: Location
  tags: Tags
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
    vmTemplate: '{"domain":"${DomainName}","galleryImageOffer":null,"galleryImagePublisher":null,"galleryImageSKU":null,"imageType":"CustomImage","imageUri":null,"customImageId":"${ComputeGalleryImageId}","namePrefix":"${VmPrefix}","osDiskType":"${DiskSku}","useManagedDisks":true,"vmSize":{"id":"${VmSize}","cores":null,"ram":null},"galleryItemId":null}'
  }
}

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2022-04-01-preview' = {
  name: AppGroupName
  location: Location
  tags: Tags
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'Desktop'
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2022-04-01-preview' = if(WorkspaceName != 'none') {
  name: WorkspaceName
  location: Location
  tags: Tags
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
output HostPoolRegistrationToken string = reference(hostPool.id).registrationInfo.token
output ComputeImageGalleryID string = ComputeGalleryImageId
