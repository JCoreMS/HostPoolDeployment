param ComputeGalleryName string = 'cgvaavdimages'
param ComputeGalleryRG string = 'rg-va-images'
param ImageName string = 'win10office22h2'

resource computeGalleryImage 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
  name: '${ComputeGalleryName}/${ImageName}'
  scope: resourceGroup(ComputeGalleryRG)
}

output computeGalleryInfo object = computeGalleryImage.properties
output securityType string = computeGalleryImage.properties.features[0].value
