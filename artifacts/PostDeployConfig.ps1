[Cmdletbinding()]
Param(
    [parameter(Mandatory)]
    [bool]
    $AllAppsUpdate,
    [parameter(Mandatory)]
    [bool]
    $WindowsUpdate
)

if($AllAppsUpdate){
    # Install WinGet App Packaging Utility for use of WinGet
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe

    # Winget to update all Apps
    & winget.exe upgrade --all -h -l 'C:\WingetUpdt.log'
}
if($WindowsUpdate){
    # Windows Update Exectution
    Install-Module -Name PSWindowsUpdate -Force -AllowClobber
    Import-Module -Name PSWindowsUpdate -Force -AllowClobber
    Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot
}