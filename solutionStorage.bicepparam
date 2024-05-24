using './solutionStorage.bicep'

param domainJoinUserName = 'jcore@corefamily.net'
param domainJoinUserPassword = 'P@lmtree5P1per28r$'
param groupAdmins = 'azAVDAdmins_MAC'
param groupUsers = 'azAVDUsers_MAC'
param keyVaultName = 'kv-corefamily01b'
param location = 'eastus2'
param managedIdentityName = 'id-stgcorefamily01'
param ouPath = 'OU=Servers,DC=corefamily,DC=net'
param privateDNSZoneId = '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-LandingZone/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net'
param smbSettings = {
        versions: 'SMB3.1.1'
        authenticationMethods: 'Kerberos'
        kerberosTicketEncryption: 'AES-256'
        channelEncryption: 'AES-256-GCM'
      }
param storageAcctName = 'stgcorefamily01'
param storageFileShareName = 'fslogix1'
param storageResourceGroup = 'rg-eus2-corefamily-01'
param storageShareSize = 500
param storageSKU = 'Standard_LRS'
param subnetId = '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-LandingZone/providers/Microsoft.Network/virtualNetworks/vnet-EastUS2-AVDLab/subnets/subnet-eastus2-AVDLab-HostPoolVMs'
param tags = {}
param tenantId = 'e5df932b-82ca-4872-a0bb-f880a766a051'
param vmName = 'vme2stmgmt01'  // 15 characters or less
param vmAdminPassword =  'P@lmtree5lab'
param vmAdminUsername =  'vmadmin'
