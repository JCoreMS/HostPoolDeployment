

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

    [Parameter(Mandatory)]
    [String]$Cloud,

    [Parameter(Mandatory)]
    [String]$OUPath,

    [Parameter(Mandatory)]
    [String]$StorageAccountResourceGroupName,

    [Parameter(Mandatory = $false)]
    [String]$AltStorageAcct = 'none',

    [Parameter(Mandatory)]
    [String]$StorageAccountName,

    [Parameter(Mandatory)]
    [String]$StorageFileShareName,

    [Parameter(Mandatory)]
    [String]$SubscriptionId,

    [Parameter(Mandatory)]
    [String]$TenantId,

    [Parameter(Mandatory)]
    [String]$StorageSetupId
)

$ErrorActionPreference = 'Stop'


try {

    ##############################################################
    #  Logging Function
    ##############################################################
    function Write-Log {
        param(
            [parameter(Mandatory)]
            [string]$Message,

            [parameter(Mandatory)]
            [string]$Type
        )
        $Path = 'C:\cse_FileShareSetup.txt'
        if (!(Test-Path -Path $Path)) {
            New-Item -Path C:\ -Name cse_FileShareSetup.txt | Out-Null
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

    # Check if Domain Joined VM
    $DomainJoined = if ($ENV:COMPUTERNAME -eq $ENV:USERDNSDOMAIN) {
        $false
        Write-Log -Message "Not Domain Joined" -Type 'ERROR'
        throw "VM is not Domain Joined! Unable to proceed with domain join storage account."
    }
    else { $true }

    Write-Log -Message "VM is Domain Joined: $DomainJoined" -Type 'PRE-REQ'

    # Disable Edge First Run
    Write-Log -Message "Disable Edge First Run Experience via Registry" -Type 'PRE-REQ'
    reg add HKLM\Software\Policies\Microsoft\Edge /v HideFirstRunExperience /t REG_DWORD /d 1 /f

    # Disable Windows Welcome Screen
    Write-Log -Message "Disable Windows Welcome Screen via Registry" -Type 'PRE-REQ'
    reg add HKEY_USERS\.DEFAULT\Software\Policies\Microsoft\Windows\CloudContent /v disablewindowsSpotlightwindowswelcomeExperience /t REG_DWORD /d 1 /f
    reg add HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f
    reg add HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f
    reg add HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f
    reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE /v DisablePrivacyExperience /t REG_DWORD /d 1 /f

    <#  Write-Log -Message "Checking for PowerShell 7" -Type 'PRE-REQ'
    $PSVersion = $PSVersionTable.PSVersion.Major
    If($PSVersion -lt 7) {
        write-Log -Message "Installing PowerShell 7" -Type 'PRE-REQ'
        Invoke-WebRequest -Uri https://github.com/PowerShell/PowerShell/releases/download/v7.4.4/PowerShell-7.4.4-win-x64.msi -OutFile C:\Windows\Temp\PowerShell-7.4.4-win-x64.msi -UseBasicParsing
        msiexec.exe /package C:\Windows\Temp\PowerShell-7.4.4-win-x64.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1
        Remove-Item -Path C:\Windows\Temp\PowerShell-7.4.4-win-x64.msi -Force
    }
    else { Write-Log -Message "PowerShell 7 already installed" -Type 'PRE-REQ' }
 #>

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Log -Message "Getting PowerShell Providers List" -Type 'PRE-REQ'
    $providers = get-packageprovider -ListAvailable

    Write-Log -Message "...Checking and installing RSAT for Active Directory" -Type 'PRE-REQ'
    $RSATAD = Get-WindowsCapability -Name RSAT* -Online | Where-Object DisplayName -Match "Active Directory Domain Services" | Select-Object -Property DisplayName, State
    If ($RSATAD.State -eq "NotPresent") {
        Get-WindowsCapability -Name RSAT* -Online | Where-Object DisplayName -Match "Active Directory Domain Services" | Add-WindowsCapability -Online
    }
    else { Write-Log -Message "---RSAT for Active Directory already installed" -Type 'PRE-REQ' }

    If ($AltStorageAcct -eq 'none') {

        Write-Log -Message "...Checking and loading NuGet provider" -Type 'PRE-REQ'
        If ($providers.Name -notcontains "NuGet") {
            Install-packageprovider -Name "NuGet" -Force | Out-Null
        }
        else { Write-Log -Message "---Package Management (NuGet) provider already installed" -Type 'PRE-REQ' }

        Write-Log -Message "...Checking and installing RSAT for Active Directory" -Type 'PRE-REQ'
        $RSATAD = Get-WindowsCapability -Name RSAT* -Online | Where-Object DisplayName -Match "Active Directory Domain Services" | Select-Object -Property DisplayName, State
        If ($RSATAD.State -eq "NotPresent") {
            Get-WindowsCapability -Name RSAT* -Online | Where-Object DisplayName -Match "Active Directory Domain Services" | Add-WindowsCapability -Online
        }
        else { Write-Log -Message "---RSAT for Active Directory already installed" -Type 'PRE-REQ' }

        $modules = get-module -ListAvailable

        Write-Log -Message "...Checking and loading ActiveDirectory Module" -Type 'PRE-REQ'
        If ($modules.name -notcontains "ActiveDirectory") {
            Install-Module -Name "ActiveDirectory" -Force | Out-Null
        }
        else { Write-Log -Message "---ActiveDirectory Module already installed" -Type 'PRE-REQ' }
        Write-Log -Message "...Checking and loading Az.Storage Module" -Type 'PRE-REQ'
        If ($modules.name -notcontains "Az.Storage") {
            Install-Module -Name "Az.Storage" -Force | Out-Null
        }
        else { Write-Log -Message "---Az.Storage Module already installed" -Type 'PRE-REQ' }

    }
    else {
        # Copy modules from storage
        Write-Log -Message "Alternate Storage Location Specified: $AltStorageAcct" -Type 'WARN'

        Write-Log -Message "Copying PS Modules" -Type 'PRE-REQ'
        Invoke-WebRequest -Uri "$AltStorageAcct/PSModules.zip" -OutFile "C:\Windows\Temp\PSModules.zip" -UseBasicParsing

        Write-Log -Message "Extracting PS Modules" -Type 'PRE-REQ'
        Expand-Archive -Path "C:\Temp\PSModules.zip" -Destination "C:\Program Files\PowerShell\7\Modules" -Force

        # Import Modules
        Write-Log -Message "Importing Module: Windows Compatibility" -Type 'PRE-REQ'
        Import-module -Name WindowsCompatibility
        Write-Log -Message "Importing Module: Active Directory" -Type 'PRE-REQ'
        Import-Module -Name ActiveDirectory
        Write-Log -Message "Importing Module: Azure Accounts" -Type 'PRE-REQ'
        Import-Module -Name Az.Accounts
        Write-Log -Message "Importing Module: Azure Storage" -Type 'PRE-REQ'
        import-module -Name Az.Storage

    }




    ##############################################################
    #  Variables
    ##############################################################
    # Get Domain information
    $Domain = Get-WMIObject Win32_ComputerSystem | Select-Object -ExpandProperty Domain

    Write-Log -Message "Collected domain information: $Domain" -Type 'INFO'

    # Create Domain credential
    Write-Log -Message "--- Creating Domiain Credentials" -Type 'INFO'
    $DomainUsername = $DomainJoinUserPrincipalName
    $DomainPassword = ConvertTo-SecureString -String $DomainJoinPassword -AsPlainText -Force
    [pscredential]$DomainCredential = New-Object System.Management.Automation.PSCredential ($DomainUsername, $DomainPassword)

    # Get Domain information
    Write-Log -Message "--- Getting Domain Information" -Type 'INFO'
    $Domain = Get-ADDomain -Credential $DomainCredential -Current 'LocalComputer'
    $Netbios = $Domain.NetBIOSName

    Write-Log -Message "Created domain join credential object" -Type 'INFO'

    ##############################################################
    #  Process Storage Resources
    ##############################################################
    $UsersGroup = $Netbios + '\' + $AclUsers
    $AdminGroup = $Netbios + '\' + $AclAdmins
    $SubscriptionId = $SubscriptionId.ToString()
    $TenantId = $TenantId.ToString()
    $Cloud = $Cloud.ToString()
    $StorageSetupId = $StorageSetupId.ToString()
    # Connects to Azure using a User Assigned Managed Identity
    Write-Log -Message "Authenticating to Azure ---> AccountID: $StorageSetupId | Environment: $Cloud | Tenant: $TenantId | Subscription: $SubscriptionId" -Type 'DEBUG'
    Connect-AzAccount -Identity -AccountId $StorageSetupId -Environment $Cloud -Tenant $TenantId -Subscription $SubscriptionId
    Write-Log -Message "Authenticated to Azure" -Type 'INFO'

    # Set Azure storage suffix
    $FileServer = ((Get-AzStorageAccount -StorageAccountName $StorageAccountName -ResourceGroupName $StorageAccountResourceGroupName).PrimaryEndpoints.file -split '/')[2]

    # Get the storage account key
    $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName)[0].Value
    Write-Log -Message "The GET operation for the Storage Account key on $StorageAccountName succeeded" -Type 'INFO'

    # Create credential for accessing the storage account
    $StorageUsername = '.\' + $StorageAccountName
    $StoragePassword = ConvertTo-SecureString -String "$($StorageKey)" -AsPlainText -Force
    [pscredential]$StorageKeyCredential = New-Object System.Management.Automation.PSCredential ($StorageUsername, $StoragePassword)

    # Get / create kerberos key for Azure Storage Account
    $KerberosKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -ListKerbKey | Where-Object { $_.Keyname -contains 'kerb1' }).Value
    if (!$KerberosKey) {
        New-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -KeyName kerb1 | Out-Null
        $Key = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -ListKerbKey | Where-Object { $_.Keyname -contains 'kerb1' }).Value
        Write-Log -Message "Kerberos Key creation on Storage Account, $StorageAccountName, succeeded." -Type 'INFO'
    }
    else {
        $Key = $KerberosKey
        Write-Log -Message "Acquired Kerberos Key from Storage Account, $StorageAccountName." -Type 'INFO'
    }

    # Creates a password for the Azure Storage Account in AD using the Kerberos key
    $ComputerPassword = ConvertTo-SecureString -String $Key.Replace("'", "") -AsPlainText -Force
    Write-Log -Message "Secure string conversion succeeded" -Type 'INFO'

    # Create the SPN value for the Azure Storage Account; attribute for computer object in AD
    $SPN = 'cifs/' + $StorageAccountName + $FilesSuffix

    # Create the Description value for the Azure Storage Account; attribute for computer object in AD
    $Description = "Computer account object for Azure storage account $($StorageAccountName)."

    # Create the AD computer object for the Azure Storage Account
    $Computer = Get-ADComputer -Credential $DomainCredential -Filter { Name -eq $StorageAccountName }
    if ($Computer) {
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
    $Key = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName -ListKerbKey | Where-Object { $_.Keyname -contains 'kerb1' }).Value
    Write-Log -Message "Resetting the Kerberos key on the Storage Account succeeded" -Type 'INFO'

    # Update the password on the computer object with the new Kerberos key on the Storage Account
    $NewPassword = ConvertTo-SecureString -String $Key -AsPlainText -Force
    Set-ADAccountPassword -Credential $DomainCredential -Identity $DistinguishedName -Reset -NewPassword $NewPassword | Out-Null
    Write-Log -Message "Setting the new Kerberos key on the Computer Object succeeded" -Type 'INFO'


    # Mount file share
    $FileShare = "\\" + $FileServer + "\" + $StorageFileShareName
    Write-Log -Message "FileShare: $FileShare  | StorageKey: $StorageKey" -Type 'DEBUG'
    New-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Root $FileShare -Credential $StorageKeyCredential | Out-Null
    # New-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Root $FileShare -Credential $DomainCredential | Out-Null
    Write-Log -Message "Mounting the Azure file share, $FileShare, succeeded" -Type 'INFO'


    # Set recommended NTFS permissions on the file share
    $ACL = Get-Acl -Path 'Z:'
    $CreatorOwner = New-Object System.Security.Principal.Ntaccount ("Creator Owner")
    $ACL.PurgeAccessRules($CreatorOwner)
    $AuthenticatedUsers = New-Object System.Security.Principal.Ntaccount ("Authenticated Users")
    $ACL.PurgeAccessRules($AuthenticatedUsers)
    $Users = New-Object System.Security.Principal.Ntaccount ("Users")
    $ACL.PurgeAccessRules($Users)
    $DomainUsers = New-Object System.Security.AccessControl.FileSystemAccessRule("$UsersGroup", "Modify", "None", "None", "Allow")
    $ACL.SetAccessRule($DomainUsers)
    $AdminUsers = New-Object System.Security.AccessControl.FileSystemAccessRule("$AdminGroup", "Full", "None", "None", "Allow")
    $ACL.SetAccessRule($AdminUsers)
    $CreatorOwner = New-Object System.Security.AccessControl.FileSystemAccessRule("Creator Owner", "Modify", "ContainerInherit,ObjectInherit", "InheritOnly", "Allow")
    $ACL.AddAccessRule($CreatorOwner)
    $ACL | Set-Acl -Path 'Z:' | Out-Null
    Write-Log -Message "Setting the NTFS permissions on the Azure file share succeeded" -Type 'INFO'

    # Unmount file share
    Remove-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Force | Out-Null
    Start-Sleep -Seconds 5 | Out-Null
    Write-Log -Message "Unmounting the Azure file share, $FileShare, succeeded" -Type 'CLEANUP'

    # Lockdown Storage Account to Kerberos Only and 256-bit Encryption
    Update-AzStorageFileServiceProperty -ResourceGroupName $StorageAccountResourceGroupName -AccountName $StorageAccountName `
    -SMBProtocolVersion SMB3.0,SMB3.1.1  `
    -SMBAuthenticationMethod Kerberos `
    -SMBKerberosTicketEncryption AES-256 `
    -SMBChannelEncryption AES-256-GCM | Out-Null
    Write-Log -Message "Storage Account locked down to Kerberos Only and 256-bit Encryption" -Type 'INFO'

    Disconnect-AzAccount | Out-Null
    Write-Log -Message "Disconnection from Azure succeeded" -Type 'INFO'
    Write-Log -Message "Storage Account Domain Joined, NTFS Permissions configured!" -Type 'COMPLETED'

    Write-Log -Message "FINISHED - Shutting down the VM" -Type 'INFO'
    Get-AzVM -Name $ENV:COMPUTERNAME | Stop-AzVM -Force | Out-Null
}
catch {
    Write-Log -Message $_ -Type 'ERROR'
    $ErrorData = $_ | Select-Object *
    $ErrorData | Out-File -FilePath 'C:\cse_FileShareSetup.txt' -Append -Encoding 'UTF8'
    throw
}