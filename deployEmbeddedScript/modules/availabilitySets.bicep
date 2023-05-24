param AvailabilitySetCount int
param AvailabilitySetPrefix string
param Location string
param Tags object

resource availabilitySet 'Microsoft.Compute/availabilitySets@2023-03-01' = [for i in range(0, AvailabilitySetCount): {
  name: '${AvailabilitySetPrefix}${padLeft(i, 3, '0')}'
  location: Location
  tags: Tags
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformUpdateDomainCount: 5
    platformFaultDomainCount: 2
  }
}]
