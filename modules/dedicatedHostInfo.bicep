targetScope = 'resourceGroup'

param dedicatedHostId string


var DedicatedHostGroupName = split(dedicatedHostId, '/')[8]
var DedicatedHostName = split(dedicatedHostId, '/')[10]

resource HostGroup 'Microsoft.Compute/HostGroups@2020-12-01' existing = {
  name: DedicatedHostGroupName
}

resource DedicatedHost 'Microsoft.Compute/hostGroups/hosts@2023-09-01' existing = {
  name: DedicatedHostName
}

output Hosts array = HostGroup.properties.hosts
output Zones array = HostGroup.zones
