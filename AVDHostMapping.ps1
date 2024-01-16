

[Cmdletbinding()]
Param(
    [parameter(Mandatory)]
    [string]
    $Environment,

    [parameter(Mandatory)]
    [string]
    $TenantId,

    [parameter(Mandatory)]
    [string]
    $SubscriptionId
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'
$query = @"
resources
| where type =~ "microsoft.desktopvirtualization/hostpools"
| extend HostPoolName = tostring(name)
| extend HostPoolRG = tostring(split(id, '/')[4])
| extend AppGroup = tostring(split(properties.applicationGroupReferences[0], '/')[8])
| extend HostPoolId = tostring(id)
| join (
    desktopvirtualizationresources
    | where type == "microsoft.desktopvirtualization/hostpools/sessionhosts"
    | extend HostPoolName = tostring(split(name, '/')[0])
    | extend SessionHosts = tostring(split(name, '/')[1])
    | extend VMResGroup = tostring(split(properties.resourceId, '/')[4])
    | extend VMResGroupId = tostring(split(properties.resourceId, '/providers')[0])
) on HostPoolName
| summarize SessionHosts = make_list(SessionHosts) by HostPoolName,VMResGroup,HostPoolRG,HostPoolId,VMResGroupId,AppGroup
"@

try 
{
    Connect-AzAccount -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId -Identity | Out-Null
    # Install the Resource Graph module from PowerShell Gallery
    Install-Module -Name Az.ResourceGraph
    $Mapping = Search-AzGraph -Query $query

    $JsonOutput = $Mapping | ConvertTo-Json -Depth 100
    return $JsonOutput
}
catch 
{
    throw
}
