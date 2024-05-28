<#
MIT License

Copyright (c) 2022 Jason Masten

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

.SYNOPSIS
Domain joins an Azure Storage Account
.DESCRIPTION
This script will add a storage account to Active Directory Domain Services as a computer object to support kerberos authentication.
.PARAMETER Environment
The name of the Azure environment.
.PARAMETER KerberosEncryptionType
The type of kerberos encrpytion used on the session hosts, the storage account, and domain controllers.
.PARAMETER OuPath
The distinguished name of the organizational unit in Active Directoy Domain Services.
.PARAMETER StorageAccountName
The name of the Azure Storage Account.
.PARAMETER StorageAccountResourceGroupName
The Resource Group name of the Azure Storage Account.
.PARAMETER SubscriptionId
The ID of the Azure Subscription.
.PARAMETER TenantId
The ID of the Azure Active Directory tenant.
.NOTES
  Version:              1.4
  Author:               Jason Masten / Jonathan Core
  Creation Date:        2023-02-16
  Last Modified Date:   2024-05-23

  - 1.4 (2024-05-23)
    - (Jonathan Core) Added NTFS permissions to the file share and logging.

.EXAMPLE
.\Set-AzureFilesKerberosAuthentication.ps1 `
    -Environment 'AzureCloud' `
    -KerberosEncryptionType 'RC4' `
    -OuPath 'OU=AVD,DC=Fabrikam,DC=COM' `
    -StorageAccountName 'saavdpeus' `
    -StorageAccountResourceGroupName 'rg-avd-p-eus' `
    -SubscriptionId '00000000-0000-0000-0000-000000000000' `
    -TenantId '00000000-0000-0000-0000-000000000000'
    -AclUsers 'AVD Users Group Name'
    -AclAdmins 'AVD Admins Group Name'
    -StorageFileShareName 'File Share Name'

This example domain joins an Azure Storage Account to the AVD organizational unit in the Fabrikam.com domain.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$KerberosEncryptionType,
    [Parameter(Mandatory = $true)]
    [string]$OuPath,
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
    [Parameter(Mandatory = $true)]
    [string]$AclUsers,
    [Parameter(Mandatory = $true)]
    [string]$AclAdmins,
    [Parameter(Mandatory = $true)]
    [string]$StorageFileShareName,
    [Parameter(Mandatory = $true)]
    [string]$DomainUser,
    [Parameter(Mandatory = $true)]
    [string]$DomainPassword  # passed via protected section of BICEP so encrypted
)
$TESTING = $true
$ErrorActionPreference = 'Stop'
$Environment = (Get-AzContext).Environment.Name


try {

    ##############################################################
    #  Logging Function
    ##############################################################
    function Write-Log {
        param
        (
            [Parameter(Mandatory = $true)]
            [String]$Message
        )

        $LogPath = 'C:\domainJoinStorageAcct.log'
        $Date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $LogMessage = "$Date - $Message"

        Add-Content -Path $LogPath -Value $LogMessage
    }

    ##############################################################
    #  Pre-requisites
    ##############################################################

    Write-Log " =================================================================="
    Write-Log "|         NEW EXECUTION OF DOMAIN JOIN STORAGE ACCOUNT             |"
    Write-Log " =================================================================="
    Write-Log "Verifying PowerShell Modules Needed"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Log "...Checking and loading NuGet provider"
    $providers = get-packageprovider -ListAvailable
    If ($providers.Name -notcontains "NuGet") {
        Install-packageprovider -Name "NuGet" -Force | Out-Null
    }
    else { Write-Log "---NuGet provider already installed" }

    Write-Log "...Checking and installing RSAT for Active Directory"
    $RSATAD = Get-WindowsCapability -Name RSAT* -Online | Where DisplayName -Match "Active Directory Domain Services" | Select-Object -Property DisplayName, State
    If ($RSATAD.State -eq "NotPresent") {
        Get-WindowsCapability -Name RSAT* -Online | Where DisplayName -Match "Active Directory Domain Services" | Add-WindowsCapability -Online
    }
    else { Write-Log "---RSAT for Active Directory already installed" }

    $modules = get-module -ListAvailable

    Write-Log "...Checking and loading ActiveDirectory Module"
    If ($modules.name -notcontains "ActiveDirectory") {
        Install-Module -Name "ActiveDirectory" -Force | Out-Null
    }
    else { Write-Log "---ActiveDirectory Module already installed" }

    Write-Log "...Checking and loading Az.Storage Module"
    If ($modules.name -notcontains "Az.Storage") {
        Install-Module -Name "Az.Storage" -Force | Out-Null
    }
    else { Write-Log "---Az.Storage Module already installed" }


    ##############################################################
    #  Variables
    ##############################################################
    # Set Azure storage suffix
    $storageFQDN = ((Get-AzStorageAccount -StorageAccountName $StorageAccountName -ResourceGroupName $StorageAccountResourceGroupName).PrimaryEndpoints.file -split '/')[2]


    # Get Domain information
    $Domain = Get-ADDomain `
        -Current 'LocalComputer'

    Write-Log "Collected domain information"

    #Domain Creds
    # Convert to SecureString
    [securestring]$secStringPassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force

    # Create PSCredential object
    [pscredential]$DomainJoineCredObj = New-Object System.Management.Automation.PSCredential($DomainUser, $secStringPassword)


    ##############################################################
    #  Process Storage Resources
    ##############################################################
    # Connect to Azure
    Connect-AzAccount `
        -Environment $Environment `
        -Tenant $TenantId `
        -Subscription $SubscriptionId -Identity | Out-Null

    Write-Log "Connected to the target Azure Subscription"


    # Create the Kerberos key for the Azure Storage Account
    $Key = (New-AzStorageAccountKey `
            -ResourceGroupName $StorageAccountResourceGroupName `
            -Name $StorageAccountName `
            -KeyName 'kerb1' `
        | Select-Object -ExpandProperty 'Keys' `
        | Where-Object { $_.Keyname -eq 'kerb1' }).Value

    Write-Log "Captured the Kerberos key for the Storage Account"


    # Creates a password for the Azure Storage Account in AD using the Kerberos key
    $ComputerPassword = ConvertTo-SecureString `
        -String $Key `
        -AsPlainText `
        -Force

    Write-Log "Created the computer object password for the Azure Storage Account in AD DS"


    # Create the SPN value for the Azure Storage Account; attribute for computer object in AD
    $SPN = 'cifs/' + $StorageAccountName + $FilesSuffix


    # Create the Description value for the Azure Storage Account; attribute for computer object in AD
    $Description = "Computer account object for Azure storage account $($StorageAccountName)."


    # Check for existing AD computer object for the Azure Storage Account
    $Computer = Get-ADComputer `
        -Filter { Name -eq $StorageAccountName } `

    Write-Log "Checked for an existing computer object for the Azure Storage Account in AD DS"

    # Remove existing AD computer object for the Azure Storage Account
    if ($Computer) {
        Remove-ADComputer `
            -Identity $StorageAccountName `
            -Confirm:$false `
            -Credential $DomainJoineCredObj

        Write-Log "Removed an existing computer object for the Azure Storage Account in AD DS"
    }


    # Create AD computer object for the Azure Storage Account
    $ComputerObject = New-ADComputer `
        -Name $StorageAccountName `
        -Path $OuPath `
        -ServicePrincipalNames $SPN `
        -AccountPassword $ComputerPassword `
        -Description $Description `
        -AllowReversiblePasswordEncryption $false `
        -Enabled $true `
        -PassThru `
        -Credential $DomainJoineCredObj

    Write-Log "Created a new computer object for the Azure Storage Account in AD DS"

    # Update the Azure Storage Account with the domain join 'INFO'
    $SamAccountName = switch ($KerberosEncryptionType) {
        'AES256' { $StorageAccountName }
        'RC4' { $ComputerObject.SamAccountName }
    }

    Set-AzStorageAccount `
        -ResourceGroupName $StorageAccountResourceGroupName `
        -Name $StorageAccountName `
        -EnableActiveDirectoryDomainServicesForFile $true `
        -ActiveDirectoryDomainName $Domain.DNSRoot `
        -ActiveDirectoryNetBiosDomainName $Domain.NetBIOSName `
        -ActiveDirectoryForestName $Domain.Forest `
        -ActiveDirectoryDomainGuid $Domain.ObjectGUID `
        -ActiveDirectoryDomainSid $Domain.DomainSID `
        -ActiveDirectoryAzureStorageSid $ComputerObject.SID.Value `
        -ActiveDirectorySamAccountName $SamAccountName `
        -ActiveDirectoryAccountType 'Computer' | Out-Null

    Write-Log "Updated the Azure Storage Account with the domain and computer object properties"


    ##############################################################
    #  Map Azure Files Share to Drive letter
    ##############################################################
    $storageKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName).Value[0]

    $fileShareFull = "\\$StorageFQDN\$StorageFileShareName"

    Write-Log "Mapping Azure Files Share to Drive Letter"


    $connectTestResult = Test-NetConnection -ComputerName $storageFQDN -Port 445
    if ($connectTestResult.TcpTestSucceeded) {
        # Save the password so the drive will persist on reboot
        #Storage Creds
        # Convert to SecureString
        [securestring]$secStringStorPassword = ConvertTo-SecureString "Azure\$StorageAccountName" -AsPlainText -Force

        # Create PSCredential object
        [pscredential]$StorageCredObj = New-Object System.Management.Automation.PSCredential("Azure\$StorageAccountName", $secStringStorPassword)
        # Mount the drive
        New-PSDrive -Name Z -PSProvider FileSystem -Root $fileShareFull -Credential $StorageCredObj
    }
    else {
        Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
    }


    ##############################################################
    #  Set NTFS Permissions on File Share
    ##############################################################

    Write-Log "Setting NTFS Permissions on File Share"
    $DomainName = $Domain.DNSRoot
    # Remove Inheritance
    Write-Log "...Removing Inheritance"
    $NewAcl = Get-Acl -Path 'Z:\'
    $isProtected = $true
    $preserveInheritance = $true
    $NewAcl.SetAccessRuleProtection($isProtected, $preserveInheritance)
    Set-Acl -Path 'Z:\' -AclObject $NewAcl

    # Modify Creator Owner permissions
    Write-Log "...Modifying Creator Owner permissions"
    $NewAcl = Get-Acl -Path 'Z:\'
    $identity = New-Object System.Security.Principal.NTAccount("Creator Owner")
    $fileSystemRights = "Modify, Synchronize"
    $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagationFlags = [System.Security.AccessControl.PropagationFlags]::InheritOnly -bor [System.Security.AccessControl.PropagationFlags]::NoPropagateInherit
    $type = "Allow"

    $fileSystemAccessRuleArgumentList = $identity, $fileSystemRights, $inheritanceFlags, $propagationFlags, $type
    $fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $fileSystemAccessRuleArgumentList

    $NewAcl.SetAccessRule($fileSystemAccessRule)
    Set-Acl -Path 'Z:\' -AclObject $NewAcl

    # Configure AVD USers Group with Modify permissions
    Write-Log "...Configuring AVD Users Group with Modify permissions"
    $NewAcl = Get-Acl -Path 'Z:\'
    $identity = "$DomainName\$AclUsers"
    $fileSystemRights = "Modify, Synchronize"
    $type = "Allow"

    $fileSystemAccessRuleArgumentList = $identity, $fileSystemRights, $type
    $fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $fileSystemAccessRuleArgumentList

    $NewAcl.SetAccessRule($fileSystemAccessRule)
    Set-Acl -Path 'Z:\' -AclObject $NewAcl

    # Configure AVD Admins Group with Full Control permissions
    Write-Log "...Configuring AVD Admins Group with Full Control permissions"
    $NewAcl = Get-Acl -Path 'Z:\'
    $identity = "$DomainName\$AclUsers"
    $fileSystemRights = "FullControl"
    $type = "Allow"

    $fileSystemAccessRuleArgumentList = $identity, $fileSystemRights, $type
    $fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $fileSystemAccessRuleArgumentList

    $NewAcl.SetAccessRule($fileSystemAccessRule)
    Set-Acl -Path 'Z:\' -AclObject $NewAcl

    ##############################################################
    #  Remove Mapped Azure Files Share to Drive letter
    ##############################################################

    Write-Log "REMOVING Mapped Drive to Azure Files Share"
    Remove-PSDrive -Name "Z" -Force

    ##############################################################
    #  Enable AES256 Encryption
    ##############################################################

    # Enable AES256 encryption if selected
    if ($KerberosEncryptionType -eq 'AES256') {
        # Set the Kerberos encryption on the computer object
        Set-ADComputer `
            -Identity $ComputerObject.DistinguishedName `
            -KerberosEncryptionType 'AES256' `
            -Credential $DomainJoineCredObj

        Write-Log "Set AES256 Kerberos encryption on the computer object for the Azure Storage Account in AD DS"


        # Reset the Kerberos key on the Storage Account
        $Key = (New-AzStorageAccountKey `
                -ResourceGroupName $StorageAccountResourceGroupName `
                -Name $StorageAccountName `
                -KeyName 'kerb1' `
            | Select-Object -ExpandProperty 'Keys' `
            | Where-Object { $_.Keyname -eq 'kerb1' }).Value

        Write-Log "Created a new Kerberos key on the Azure Storage Account to support AES256 Kerberos encryption"


        # Capture the Kerberos key as a secure string
        $NewPassword = ConvertTo-SecureString `
            -String $Key `
            -AsPlainText `
            -Force

        Write-Log "Created the computer object password for the Azure Storage Account in AD DS to support AES256 Kerberos encryption"


        # Update the password on the computer object with the new Kerberos key from the Storage Account
        Set-ADAccountPassword `
            -Identity $ComputerObject.DistinguishedName `
            -Reset `
            -NewPassword $NewPassword `
            -Credential $DomainJoineCredObj

        Write-Log "Updated the password on the computer object for the Azure Storage Account in AD DS"
    }

    Write-Log "DONE!"
}
catch {
    Write-Log "ERROR: $_"
    throw
}