# USMC_HostPool

# Custom UI Definition

| Deployment Type | Link |
|:--|:--|
| Azure portal UI |[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FUSMC_HostPool%2Fmain%2Fworkload%2Farm%2Fdeploy-baseline.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Favdaccelerator%2Fmain%2Fworkload%2Fportal-ui%2Fportal-ui-baseline.json) [![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FUSMC_HostPool%2Fmain%2Fworkload%2Farm%2Fdeploy-baseline.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Favdaccelerator%2Fmain%2Fworkload%2Fportal-ui%2Fportal-ui-baseline.json)|


## PowerShell to convert URL
```Powershell
$AVDAccelURL = “https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Favdaccelerator%2Fmain%2Fworkload%2Farm%2Fdeploy-baseline.json/uiFormDefinitionUri/”
Add-Type -AssemblyName System.Web

$webURL = Read-Host "Input URL to encode/decode" 

#The below code is used to encode the URL
$urlToEncode = $webURL
$encodedURL = [System.Web.HttpUtility]::UrlEncode($urlToEncode) 

Set-Clipboard -Value $AVDAccelURL$encodedURL
Write-Host "`nResulting URL is:" -ForegroundColor Cyan
Write-Host $encodedURL

Write-Host "AVD Accelerator Deployment URL and custom URL copied to clipboard!" -ForegroundColor Yellow 
```
## Deploy To Template spec

```PowerShell
New-AzTemplateSpec -ResourceGroupName 'myRG' -Name 'myTemplateSpec' -Version 'v2.0' -Location 'West US' -TemplateFile 'myTemplateContent.json' --UIFormDefinitionFile 'myUIDefinition.json'
```
