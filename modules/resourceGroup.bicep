targetScope = 'subscription'
param RGName string
param RGStatus string
param Location string
param Tags object

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (RGStatus == 'New') {
  name: RGName
  location: Location
  tags: Tags
}

resource resourceGroupExisting 'Microsoft.Resources/resourceGroups@2022-09-01' existing = if (RGStatus == 'Existing') {
  name: RGName
}


output resourceGroupId string = RGStatus == 'Existing' ? resourceGroup.id : resourceGroupExisting.id
