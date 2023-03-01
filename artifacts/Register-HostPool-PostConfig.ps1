    
[Cmdletbinding()]
Param(
    [parameter(Mandatory)]
    [string]
    $HostPoolRegistrationToken,
    [parameter(Mandatory)]
    [string]
    $AllAppsUpdate,
    [parameter(Mandatory)]
    [string]
    $WindowsUpdate
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

########################################################################################
#                    WINDOWS AND APP UPDATES
########################################################################################

if($AllAppsUpdate){
    Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/download/v1.4.10173/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "C:\temp\WinGet.msixbundle"
    Add-AppxPackage "C:\temp\WinGet.msixbundle"

    # Winget to update all Apps
    & winget.exe upgrade -h --all
}
if($WindowsUpdate){
    # Windows Update Exectution
    Install-Module -Name PSWindowsUpdate -Force -AllowClobber
    Import-Module -Name PSWindowsUpdate -Force -AllowClobber
    Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot
}