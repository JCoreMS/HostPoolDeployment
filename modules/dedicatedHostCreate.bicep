@description('Location for the resources.')
param location string = resourceGroup().location

@description('How many Zone to use. Use 0 for non zonal deployment.')
param numberOfZoness int = 1

@description('How many hosts to create per zone.')
param numberofHostsPerZone int = 1

@description('How many fault domains to use. ')
param numberOfFDs int = 1

@description('Name (prefix) for your host group.')
param dhgNamePrefix string = 'TestHostGroup'

@description('Name (prefix) for your host .')
param dhNamePrefix string = 'TestHost'

@description('The type (family and generation) for your host .')
param dhSKU string = 'DSv5-Type1'

var numberOfHosts = ((numberOfZoness == 0) ? numberofHostsPerZone : (numberOfZoness * numberofHostsPerZone))

resource HostGroupResource 'Microsoft.Compute/HostGroups@2020-12-01' = [
  for i in range(0, ((numberOfZoness == 0) ? 1 : numberOfZoness)): {
    name: '${dhgNamePrefix}-hostgroup-${i}'
    location: location
    zones: ((numberOfZoness == 0) ? null : array((i + 1)))
    properties: {
      platformFaultDomainCount: numberOfFDs
    }
  }
]

resource DedicatedHosts 'Microsoft.Compute/hostGroups/hosts@2023-09-01' = [
  for i in range(0, numberOfHosts): {
    name: '${dhgNamePrefix}-hostgroup-${(i/numberofHostsPerZone)}/${dhNamePrefix}${(i/numberofHostsPerZone)}'
    location: location
    sku: {
      name: dhSKU
    }
    properties: {
      platformFaultDomain: (i % numberOfFDs)
    }
    dependsOn: [
      HostGroupResource[(i/numberofHostsPerZone)]
    ]
  }
]

output hostCount int = numberOfHosts
output DedicatedHosts object = DedicatedHosts[0]
