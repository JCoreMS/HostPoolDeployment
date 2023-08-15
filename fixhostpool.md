# FIX: No longer able to add Session Hosts via AVD Portal

The issue with the previous deployments that may have been used since May 2023, have updated the host pool with an invalid image Template property that would yeild a failure when adding Session Hosts via the AVD Portal. To resolve this issue it's necesary to redeploy the host pool with the corrected VM Image Template property.

To accomplish this, simply download and update the [fixHostPool.bicep](./modules/fixHostPool.bicep) file and run the PowerShell script to deploy.

## Update the BICEP file

### For the Microsoft Gallery Images

Ensure you update these with the values of the image types you plan on using going forward to include the OS version, size SKU and offer types.  Below is a list if needed:  

| OS  | Publisher |  Offer  |  SKU
|--- |--- |--- |--- |
|  win10 22h2 Gen2 | MicrosoftWindowsDesktop | windows-10 | win10-22h2-avd-g2  |
|  win10 21h2 Gen2 | MicrosoftWindowsDesktop | office-365 | win10-21h2-avd-m365-g2 |
|  win11 21h2 Gen2 | MicrosoftWindowsDesktop | windows-11 | win11-21h2-avd  |
|  win11 21h2 Gen2 | MicrosoftWindowsDesktop | office-365 | win11-21h2-avd-m365  |
|  win11 22h2 Gen2 | MicrosoftWindowsDesktop | windows-11 | win11-22h2-avd  |
|  win11 22h2 Gen2 | MicrosoftWindowsDesktop | office-365 | win11-22h2-avd-m365  |   

### For Custom Azure Compute Gallery Images

Ensure you also capture the Resource ID for the Image Definition (ComputeGaleryImageId) and set the flag denoting use of the Azure Compute Gallery (UseCustomImage) to 'true.' You can then leave the default values for the VM Publiser, VM Offer and VM SKU as they will not be used.  


```
param AppGroupType string = 'Desktop'
param CustomRdpProperty string = 'audiocapturemode:i:1;camerastoredirect:s:*;use multimon:i:0;drivestoredirect:s:;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;encode redirected video capture:i:1;redirectwebauthn:i:1;'
param DiskSku string = 'StandardSSD_LRS'
param DomainName string = 'contoso.com'
param HostPoolName string = 'hp-OfficeGenWorkers'
param HostPoolType string = 'Pooled'
param LoadBalancerType string = 'DepthFirst'
param Location string = resourceGroup().location
param NumUsersPerHost int = 2
param Timestamp string = utcNow('u')
param UseCustomImage bool = false
param StartVmOnConnect bool = true
param ComputeGalleryImageId string = ''
param VmPrefix string = 'vmAVD-'
param ValidationEnvironment bool = false
param VmSize string = 'Standard_D4s_v5'
param VmImagePub string = 'MicrosoftWindowsDesktop'
param VmOffer string = 'office-365'
param VmSku string = 'win10-21h2-avd-m365-g2'
```

## Deploy Fix

Simply ensure you are connected to Azure and authenticated by running the following command, ensuring you add the '-Environment' if connecting to the US Government or China cloud:  
```PowerShell
Connect-AzAccount
Get-AzSubscription
Set-AzContext -Subscription <name or ID of desired Subscription>
```

Deploy the updated fix which will redeploy the Host Pool with the corrected VM Template propoerties.  

```PowerSHell
New-AzResourceGroupDeployment -ResourceGroupName <name of RG> -TemplateFile <BICEP file with path> -Verbose
```
