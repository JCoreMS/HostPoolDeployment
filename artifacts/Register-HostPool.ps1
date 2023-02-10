    
[Cmdletbinding()]
Param(
    [parameter(Mandatory)]
    [string]
    $HostPoolRegistrationToken,
    [parameter(Mandatory)]
    [string]
    $XTenantRegister,
    [parameter(Mandatory)]
    [string]
    $XTenantRegToken
)
##############################################################
#  FUNCTIONS
##############################################################
function Write-Log
{
    param(
        [parameter(Mandatory)]
        [string]$Message,
        
        [parameter(Mandatory)]
        [string]$Type
    )
    $Path = 'C:\cse.txt'
    if(!(Test-Path -Path $Path))
    {
        New-Item -Path 'C:\' -Name 'cse.txt' | Out-Null
    }
    $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
    $Entry = '[' + $Timestamp + '] [' + $Type + '] ' + $Message
    $Entry | Out-File -FilePath $Path -Append
}

function Get-WebFile {
    param(
        [parameter(Mandatory)]
        [string]$FileName,
    
        [parameter(Mandatory)]
        [string]$URL
    )
    $Counter = 0
    do {
        Invoke-WebRequest -Uri $URL -OutFile $FileName -ErrorAction 'SilentlyContinue'
        if ($Counter -gt 0) {
            Start-Sleep -Seconds 30
        }
        $Counter++
    }
    until((Test-Path $FileName) -or $Counter -eq 9)
}


##############################################################
#  Install the AVD Agent
##############################################################
# Determine cross Tenant registration 
If ($XTenantRegister -eq $true) {
    Write-Log -Message "Cross Tenant Registration Configured" -Type 'INFO'
    Write-Log -Message $XTenantRegister -Type 'INFO'
    $HostPoolRegistrationToken = $XTenantRegToken
 }


# Disabling this method for installing the AVD agent until AAD Join can completed successfully
$BootInstaller = 'AVD-Bootloader.msi'
Get-WebFile -FileName $BootInstaller -URL 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'
Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $BootInstaller /quiet /qn /norestart /passive" -Wait -Passthru
Write-Log -Message 'Installed AVD Bootloader' -Type 'INFO'
Start-Sleep -Seconds 5

$AgentInstaller = 'AVD-Agent.msi'
Get-WebFile -FileName $AgentInstaller -URL 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv'
Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $AgentInstaller /quiet /qn /norestart /passive REGISTRATIONTOKEN=$HostPoolRegistrationToken" -Wait -PassThru
Write-Log -Message 'Installed AVD Agent' -Type 'INFO'
Start-Sleep -Seconds 5