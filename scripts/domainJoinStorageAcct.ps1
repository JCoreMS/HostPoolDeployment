

param
(
    [Parameter(Mandatory)]
    [String]$AclAdmins,

    [Parameter(Mandatory)]
    [String]$AclUsers,

    [Parameter(Mandatory)]
    [String]$DomainJoinPassword,

    [Parameter(Mandatory)]
    [String]$DomainJoinUserPrincipalName,

    [Parameter(Mandatory=$false)]
    [String]$Environment,

    [Parameter(Mandatory=$false)]
    [String]$OUPath,

    [Parameter(Mandatory=$false)]
    [String]$StorageAccountResourceGroupName,

    [Parameter(Mandatory=$false)]
    [String]$StorageAccountName,

    [Parameter(Mandatory=$false)]
    [String]$StorageFileShareName,

    [Parameter(Mandatory=$false)]
    [String]$SubscriptionId,

    [Parameter(Mandatory=$false)]
    [String]$TenantId,

    [Parameter(Mandatory=$false)]
    [String]$UserAssignedIdentityClientId
)

$ErrorActionPreference = 'Stop'


try {

    ##############################################################
    #  Logging Function
    ##############################################################
    function Write-Log
    {
        param(
            [parameter(Mandatory)]
            [string]$Message,

            [parameter(Mandatory)]
            [string]$Type
        )
        $Path = 'C:\cse_FileShareSetup.txt'
        if(!(Test-Path -Path $Path))
        {
            New-Item -Path C:\ -Name cse_FileShareSetup.txt| Out-Null
        }
        $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
        $Entry = '[' + $Timestamp + '] [' + $Type + '] ' + $Message
        $Entry | Out-File -FilePath $Path -Append -Encoding 'UTF8'
    }

    ##############################################################
    #  Pre-requisites
    ##############################################################

    Write-Log -Message " ==================================================================" -Type 'INFO'
    Write-Log -Message "|         NEW EXECUTION OF DOMAIN JOIN STORAGE ACCOUNT             |" -Type 'INFO'
    Write-Log -Message " ==================================================================" -Type 'INFO'
    Write-Log -Message "Verifying PowerShell Modules Needed" -Type 'INFO'

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Log -Message "...Checking and loading NuGet provider" -Type 'INFO'
    $providers = get-packageprovider -ListAvailable
    If ($providers.Name -notcontains "NuGet") {
        Install-packageprovider -Name "NuGet" -Force | Out-Null
    }
    else { Write-Log -Message "---NuGet provider already installed" -Type 'INFO' }

    Write-Log -Message "...Checking and installing RSAT for Active Directory" -Type 'INFO'
    $RSATAD = Get-WindowsCapability -Name RSAT* -Online | Where-Object DisplayName -Match "Active Directory Domain Services" | Select-Object -Property DisplayName, State
    If ($RSATAD.State -eq "NotPresent") {
        Get-WindowsCapability -Name RSAT* -Online | Where-Object DisplayName -Match "Active Directory Domain Services" | Add-WindowsCapability -Online
    }
    else { Write-Log -Message "---RSAT for Active Directory already installed" -Type 'INFO' }

    $modules = get-module -ListAvailable

    Write-Log -Message "...Checking and loading ActiveDirectory Module" -Type 'INFO'
    If ($modules.name -notcontains "ActiveDirectory") {
        Install-Module -Name "ActiveDirectory" -Force | Out-Null
    }
    else { Write-Log -Message "---ActiveDirectory Module already installed" -Type 'INFO' }

    Write-Log -Message "...Checking and loading Az.Storage Module" -Type 'INFO'
    If ($modules.name -notcontains "Az.Storage") {
        Install-Module -Name "Az.Storage" -Force | Out-Null
    }
    else { Write-Log -Message "---Az.Storage Module already installed" -Type 'INFO' }


    ##############################################################
    #  Variables
    ##############################################################
    # Get Domain information
    $Domain = Get-ADDomain `
        -Current 'LocalComputer'

    Write-Log -Message "Collected domain information" -Type 'INFO'

    # Create Domain credential
    $DomainUsername = $DomainJoinUserPrincipalName
    $DomainPassword = ConvertTo-SecureString -String $DomainJoinPassword -AsPlainText -Force
    [pscredential]$DomainCredential = New-Object System.Management.Automation.PSCredential ($DomainUsername, $DomainPassword)

    # Get Domain information
    $Domain = Get-ADDomain -Credential $DomainCredential -Current 'LocalComputer'
    $Netbios = $Domain.NetBIOSName

    Write-Log -Message "Created domain join credential object" -Type 'INFO'

    ##############################################################
    #  Process Storage Resources
    ##############################################################
    $UsersGroup = $Netbios + '\' + $AclUsers
    $AdminGroup = $Netbios + '\' + $AclAdmins

    # Connects to Azure using a User Assigned Managed Identity
    Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId | Out-Null
    Write-Log -Message "Authenticated to Azure" -Type 'INFO'

# Set Azure storage suffix
    $FileServer = ((Get-AzStorageAccount -StorageAccountName $StorageAccountName -ResourceGroupName $StorageAccountResourceGroupName).PrimaryEndpoints.file -split '/')[2]

    # Get the storage account key
    $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName)[0].Value
    Write-Log -Message "The GET operation for the Storage Account key on $StorageAccountName succeeded" -Type 'INFO'

    # Create credential for accessing the storage account
    $StorageUsername = 'Azure\' + $StorageAccountName
    $StoragePassword = ConvertTo-SecureString -String "$($StorageKey)" -AsPlainText -Force
    [pscredential]$StorageKeyCredential = New-Object System.Management.Automation.PSCredential ($StorageUsername, $StoragePassword)

    # Get / create kerberos key for Azure Storage Account
    $KerberosKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -ListKerbKey | Where-Object {$_.Keyname -contains 'kerb1'}).Value
    if(!$KerberosKey)
    {
        New-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -KeyName kerb1 | Out-Null
        $Key = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -ListKerbKey | Where-Object {$_.Keyname -contains 'kerb1'}).Value
        Write-Log -Message "Kerberos Key creation on Storage Account, $StorageAccountName, succeeded." -Type 'INFO'
    }
    else
    {
        $Key = $KerberosKey
        Write-Log -Message "Acquired Kerberos Key from Storage Account, $StorageAccountName." -Type 'INFO'
    }

    # Creates a password for the Azure Storage Account in AD using the Kerberos key
    $ComputerPassword = ConvertTo-SecureString -String $Key.Replace("'","") -AsPlainText -Force
    Write-Log -Message "Secure string conversion succeeded" -Type 'INFO'

    # Create the SPN value for the Azure Storage Account; attribute for computer object in AD
    $SPN = 'cifs/' + $StorageAccountName + $FilesSuffix

    # Create the Description value for the Azure Storage Account; attribute for computer object in AD
    $Description = "Computer account object for Azure storage account $($StorageAccountName)."

    # Create the AD computer object for the Azure Storage Account
    $Computer = Get-ADComputer -Credential $DomainCredential -Filter {Name -eq $StorageAccountName}
    if($Computer)
    {
        Remove-ADComputer -Credential $DomainCredential -Identity $StorageAccountName -Confirm:$false
    }
    $ComputerObject = New-ADComputer -Credential $DomainCredential -Name $StorageAccountName -Path $OUPath -ServicePrincipalNames $SPN -AccountPassword $ComputerPassword -Description $Description -PassThru
    Write-Log -Message "Computer object creation succeeded" -Type 'INFO'

    Set-AzStorageAccount `
        -ResourceGroupName $StorageAccountResourceGroupName `
        -Name $StorageAccountName `
        -EnableActiveDirectoryDomainServicesForFile $true `
        -ActiveDirectoryDomainName $Domain.DNSRoot `
        -ActiveDirectoryNetBiosDomainName $Domain.NetBIOSName `
        -ActiveDirectoryForestName $Domain.Forest `
        -ActiveDirectoryDomainGuid $Domain.ObjectGUID `
        -ActiveDirectoryDomainsid $Domain.DomainSID `
        -ActiveDirectoryAzureStorageSid $ComputerObject.SID.Value `
        -ActiveDirectorySamAccountName $StorageAccountName `
        -ActiveDirectoryAccountType 'Computer' | Out-Null
    Write-Log -Message "Storage Account update with domain join info succeeded" -Type 'INFO'

    # Set the Kerberos encryption on the computer object
    $DistinguishedName = 'CN=' + $StorageAccountName + ',' + $OUPath
    Set-ADComputer -Credential $DomainCredential -Identity $DistinguishedName -KerberosEncryptionType 'AES256' | Out-Null
    Write-Log -Message "Setting Kerberos AES256 Encryption on the computer object succeeded" -Type 'INFO'

    # Reset the Kerberos key on the Storage Account
    New-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -KeyName kerb1 | Out-Null
    $Key = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -ListKerbKey | Where-Object {$_.Keyname -contains 'kerb1'}).Value
    Write-Log -Message "Resetting the Kerberos key on the Storage Account succeeded" -Type 'INFO'

    # Update the password on the computer object with the new Kerberos key on the Storage Account
    $NewPassword = ConvertTo-SecureString -String $Key -AsPlainText -Force
    Set-ADAccountPassword -Credential $DomainCredential -Identity $DistinguishedName -Reset -NewPassword $NewPassword | Out-Null
    Write-Log -Message "Setting the new Kerberos key on the Computer Object succeeded" -Type 'INFO'


    # Check File Share Security for NTLMv2 or mapping will fail
    $FileShareSec = Get-AzStorageFileServiceProperty -ResourceGroupName $StorageAccountResourceGroupName -StorageAccountName $StorageAccountName
    If($FileShareSec.ProtocolSettings.Smb.AuthenticationMethods -notcontains 'NTLMv2'){
        Write-Log -Message "Missing NTLMv2 property to allow mapping, setting temporarily..." -Type 'WARN'
        Update-AzStorageFileServiceProperty -ResourceGroupName $StorageAccountResourceGroupName -AccountName $StorageAccountName `
            -SMBAuthenticationMethod Kerberos,NTLMv2 | Out-Null
        $RemoveNTLMv2 = $true
        }

    # Mount file share
    $FileShare = "\\" + $FileServer + "\" + $StorageFileShareName
    Write-Log -Message "FileShare: $FileShare  |   FileServer:  $FileServer   |   Share:  $StorageFileShareName   |  FilesSuffix:  $FilesSuffix" -Type 'DEBUG'
    New-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Root $FileShare -Credential $StorageKeyCredential | Out-Null
    Write-Log -Message "Mounting the Azure file share, $FileShare, succeeded" -Type 'INFO'


    # Set recommended NTFS permissions on the file share
    $ACL = Get-Acl -Path 'Z:'
    $CreatorOwner = New-Object System.Security.Principal.Ntaccount ("Creator Owner")
    $ACL.PurgeAccessRules($CreatorOwner)
    $AuthenticatedUsers = New-Object System.Security.Principal.Ntaccount ("Authenticated Users")
    $ACL.PurgeAccessRules($AuthenticatedUsers)
    $Users = New-Object System.Security.Principal.Ntaccount ("Users")
    $ACL.PurgeAccessRules($Users)
    $DomainUsers = New-Object System.Security.AccessControl.FileSystemAccessRule("$UsersGroup","Modify","None","None","Allow")
    $ACL.SetAccessRule($DomainUsers)
    $AdminUsers = New-Object System.Security.AccessControl.FileSystemAccessRule("$AdminGroup","Full","None","None","Allow")
    $ACL.SetAccessRule($AdminUsers)
    $CreatorOwner = New-Object System.Security.AccessControl.FileSystemAccessRule("Creator Owner","Modify","ContainerInherit,ObjectInherit","InheritOnly","Allow")
    $ACL.AddAccessRule($CreatorOwner)
    $ACL | Set-Acl -Path 'Z:' | Out-Null
    Write-Log -Message "Setting the NTFS permissions on the Azure file share succeeded" -Type 'INFO'

    # Unmount file share
    Remove-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Force | Out-Null
    Start-Sleep -Seconds 5 | Out-Null
    Write-Log -Message "Unmounting the Azure file share, $FileShare, succeeded" -Type 'INFO'

    # Remove NTLMv2 if not pre-existing
    If($RemoveNTLMv2){
        Write-Log -Message "Removing NTLMv2 property as it wasn't pre-existing..." -Type 'WARN'
        Update-AzStorageFileServiceProperty -ResourceGroupName $StorageAccountResourceGroupName -AccountName $StorageAccountName `
            -SMBAuthenticationMethod Kerberos | Out-Null
        }

    Disconnect-AzAccount | Out-Null
    Write-Log -Message "Disconnection from Azure succeeded" -Type 'INFO'
    Write-Log -Message "Storage Account Domain Joined, NTFS Permissions configured!" -Type 'COMPLETED'
}
catch {
    Write-Log -Message $_ -Type 'ERROR'
    $ErrorData = $_ | Select-Object *
    $ErrorData | Out-File -FilePath 'C:\cse_FileShareSetup.txt' -Append -Encoding 'UTF8'
    throw
}