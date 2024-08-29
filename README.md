
# AVD Host Pool Deployment

This solution was designed to provide a quick start for using Infrastructure as Code for AVD. It's a simple solution that combines a Custom UI Definition and ARM template to deploy a Host Pool, Add Session Hosts, and executes a Post Deployment Script.

Additionally the solution was written in BICEP to provide an ease of use and mechanism for customizations. To get started you will need the following:

- Azure Storage Account with a Blob Container housing your PowerShell script (Use provided PostConfig.ps1 as an example)
- VS Code for customizing the User Interface and/or code for deployment

Currently it provides a way to deploy a Host Pool with diagnostics enabled, using a KeyVault as an option for domain and local VM password(s) and from either the Microsoft Marketplace or Azure Compute Gallery. Finally, it incorporates a PowerShell script to provide additional post deployment configurations which currently has a reboot and Windows Update option. You can easily add to this script and create parameters within the provided code to then pass to the script for execution.

## Components

1. Deployment Code
This can be in either ARM format or JSON files or in BICEP which provides a more consolidated code syntax with an easier to read format as well.

2. Parameters / Input
This is what provides a way to reuse code by having an answer file sort of approach with things like naming preferences, specific Resource Groups to use, etc.

    **Parameters File** - This is a JSON based file in which you would supply the required parameters and deploy via PowerShell and possibly build a Template Spec from in Azure.

    **Custom UI Definition** - This is yet another mechanism for providing the parameters however it is a JSON file which defines a custom User Interface that is similar to what you see in the portal when deploying new resources. It can be much more user friendly and has options to hard code and hide certain inputs. Additionally it can also be compbined with the deployment code to create a Template Spec in Azure but the Template Spec must be created from PowerShell to specify a customer UI definition.

## Deploy A Host Pool or Add Session Hosts

This was created to expand on what is in the Azure Portal natively due to some scenarios that may require post move or deployment activities. The functionalities are:

1. Deploy new Host Pool and Session Hosts
2. Deploy additional Session Hosts to existing Host Pool
3. Deploy Session Hosts to an Alternate Tenant (Including Cross Cloud)
4. Deploy Session Hosts to a Dedicated Host (Per IL5 requirements)

**Deploy Host Pool or Session Hosts**  

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2Fsolution.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2FuiDefinition.json) [![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2Fsolution.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2FuiDefinition.json)

## Deploy Zero Trust Storage - AD Domain Joined Only

This will deploy the following considering Zero Trusts configuration:

1. Storage Account (With File Share for FSLogix)
2. Key Vault (Used to create and house Customer Managed Keys)
3. Management VM (Used to domain join storage and configure NTFS permissions) --AD JOIN Option--
4. Managed User Identity (mapped to the Storage Account for Key Vault Access)
5. Private DNS Endpoint (for the Storage Account)

The overall solution provides a quick way to create a Storage Account for your FSLogix needs with an AD Domain Joined scenario and assumes you have a VNet with DNS to your Domain Controllers already configured. Additionally, you'll need to ensure you have an existing Private DNS Zone for Azure Files to store the endpoint created. Lastly, you'll need to ensure the deployment has access to this GitHub site in order to pull the needed "domainJoinStorage.ps1" script to the Management VM.

### AD Join Option

Upon completion of the deployment, there will be a running VM that you'll need to shutdown or remove if not needed. The VM will also have a log file on the root of the C: Drive called `cse_FileShareSetup` for troubleshooting.

Eventually there will be an update to provide an option for the following:
A. Remove/ Delete Management VM

### Entra ID Join Option

This option does NOT use or create the management VM and requires additional AVD VM configuration per:
https://learn.microsoft.com/en-us/azure/virtual-desktop/create-profile-container-azure-ad#configure-the-session-hosts

**Deploy Zero Trust Storage**  

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2FsolutionStorage.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2FuiDefinitionStorage.json) [![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2FsolutionStorage.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2FuiDefinitionStoragegov.json)

## IaaC Info

If you'd like to host the solution on you're own GitHub repository or other publicly accessible web site you can form you're own URL from the above buttons.  Notice that the URLs are formated in the following way:

https://aka.ms/deploytoazurebutton

- URL for the button logo for Markdown

https://portal.azure.com#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/

- launches Azure Portal (change .com to .us for US Government)

/uri/'First URI segment ARM Template for deployment'
/uiFormDefinitionUri/'2nd URI Section with Custom UI Definiton JSON file'

## PowerShell to convert URL

```Powershell
Add-Type -AssemblyName System.Web

$webURL = Read-Host "Input URL to encode"
$ARMfile = Read-Host "Input the ARM template file name without the extension. (i.e. solution)"
$UIDefFile = Read-Host "Input the UI Definition file name  without the extension. (i.e. uiDefinition)"
$urlToEncode = $webURL
$encodedURL = [System.Web.HttpUtility]::UrlEncode($urlToEncode)

$CompleteURL = "https://portal.azure.com#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/$encodedURL%2F$ARMfile.json/uiFormDefinitionUri/$encodedURL%2F$UIDefFile.json"
Set-Clipboard -Value $CompleteURL
Write-Host "`nEncoded URL is:" -ForegroundColor Cyan
Write-Host $encodedURL
Write-Host "`nComplete URL is:" -ForegroundColor Cyan
Write-Host "Complete URL copied to clipboard!" -ForegroundColor Yellow
```

## Deploy To Template spec

```PowerShell
New-AzTemplateSpec -ResourceGroupName 'myRG' -Name 'DeployHostPool-Custom-UI' -Version 'v1.0' -Location 'West US' -TemplateFile 'solution.json' -UIFormDefinitionFile 'uiDefinition.json'
```