
targetScope = 'resourceGroup'

param AppGroupType string = 'Desktop'
param CustomRdpProperty string = 'audiocapturemode:i:1;camerastoredirect:s:*;use multimon:i:0;drivestoredirect:s:;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;encode redirected video capture:i:1;redirectwebauthn:i:1;'
param DiskSku string = 'StandardSSD_LRS'
param DomainName string
param HostPoolName string
param HostPoolType string = 'Pooled'
param LoadBalancerType string = 'DepthFirst'
param Location string = resourceGroup().location
param NumUsersPerHost int = 2
param Timestamp string = utcNow('u')
param UseCustomImage bool = false
param StartVmOnConnect bool = true
param ComputeGalleryImageId string = ''
param VmPrefix string
param ValidationEnvironment bool = false
param VmSize string = 'Standard_D4s_v5'
param VmImagePub string = 'MicrosoftWindowsDesktop'
param VmOffer string = 'office-365'
param VmSku string = 'win10-21h2-avd-m365-g2'

var vmGalleryItemId = '${VmImagePub}.${VmOffer}${VmSku}'
var vmTemplateMS = '{"domain":"${DomainName}","galleryImageOffer":"${VmOffer}","galleryImagePublisher":"${VmImagePub}","galleryImageSKU":"${VmSku}","imageType":"Gallery","customImageId":null,"namePrefix":"${VmPrefix}","osDiskType":"${DiskSku}","vmSize":{"id":"${VmSize}","cores":null,"ram":null},"galleryItemId":"${vmGalleryItemId}","hibernate":false,"diskSizeGB":0,"securityType":"TrustedLaunch","secureBoot":true,"vTPM":true}' 
var vmTemplateCompGal = '{"domain":"${DomainName}","galleryImageOffer":null,"galleryImagePublisher":null,"galleryImageSKU":null,"imageType":"CustomImage","imageUri":null,"customImageId":"${ComputeGalleryImageId}","namePrefix":"${VmPrefix}","osDiskType":"${DiskSku}","useManagedDisks":true,"vmSize":{"id":"${VmSize}","cores":null,"ram":null},"galleryItemId":null}' 
var vmTemplate = UseCustomImage ? vmTemplateCompGal : vmTemplateMS

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-10-14-preview' = {
  name: HostPoolName
  location: Location
  properties: {
    hostPoolType: HostPoolType
    maxSessionLimit: NumUsersPerHost
    loadBalancerType: LoadBalancerType
    validationEnvironment: ValidationEnvironment
    registrationInfo: {
      expirationTime: dateTimeAdd(Timestamp, 'PT2H')
      registrationTokenOperation: 'Update'
    }
    preferredAppGroupType: AppGroupType
    customRdpProperty: CustomRdpProperty
    personalDesktopAssignmentType: HostPoolType == 'Personal' ? HostPoolType : null
    startVMOnConnect: StartVmOnConnect // https://docs.microsoft.com/en-us/azure/virtual-desktop/start-virtual-machine-connect
    vmTemplate: vmTemplate
  }
}
