var ComputeGallery = {
  hyperVGeneration: 'V2'
  architecture: 'x64'
  /*features: [
    {
      name: 'SecurityType'
      value: 'TrustedLaunch'
    }
  ]*/
  osType: 'Windows'
  osState: 'Generalized'
  identifier: {
    publisher: 'Microsoft'
    offer: 'Win10'
    sku: 'Office'
  }
  recommended: {
    vCPUs: {
      min: 1
      max: 16
    }
    memory: {
      min: 1
      max: 32
    }
  }
  provisioningState: 'Succeeded'
}

output SecurityFeature string = contains(ComputeGallery, 'features') ? (filter(ComputeGallery, Properties => Properties.feature.name == 'SecurityType'))[0].value : null


