# AVD Host Pool Deployment

**NOTE: This solution currently breaks the ability to add session hosts via the AVD Portal natively!  Working on a resolution and will remove this text once resolved!**  
You can continue to use this solution to add Session Hosts to a Host Pool but may be forced to recreate or redploy the host pool new once the issues is resolved.  

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

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2Fsolution.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2FuiDefinition.json) [![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2Fsolution.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FHostPoolDeployment%2Fmaster%2FuiDefinition.json)

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
New-AzTemplateSpec -ResourceGroupName 'myRG' -Name 'myTemplateSpec' -Version 'v2.0' -Location 'West US' -TemplateFile 'myTemplateContent.json' -UIFormDefinitionFile 'myUIDefinition.json'
```
