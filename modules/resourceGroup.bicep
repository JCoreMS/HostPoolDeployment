targetScope = 'subscription'
param RGName string
param Location string
param Tags object

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: RGName
  location: Location
  tags: Tags
}
