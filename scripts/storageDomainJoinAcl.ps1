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
Domain joins an Azure Storage Account, Map with Storage Key, and Set NTFS Permissions on the file share.
.DESCRIPTION
This script will add a storage account to Active Directory Domain Services as a computer object to support kerberos authentication, map the storage account to a drive letter, and set NTFS permissions on the file share.
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
  Version:              1.0
  Author:               Jason Masten
  Creation Date:        2024-05-23
  Last Modified Date:   2024-05-23

.EXAMPLE
.\Set-AzureFilesKerberosAuthentication.ps1 `
    -ActiveDirectorySolution 'AzureCloud' `
    -DomainAccountType 'Computer' `
    -DomainJoinPassword 'P@ssw0rd1234' `
    -DomainJoinUserPrincipalName 'user@contoso.com' `
    -Environment 'AzureCloud' `
    -FslogixContainerType 'ProfileContainer' `
    -Netbios 'Contoso'
    -OrganizationalUnitPath 'OU=AVD,DC=Fabrikam,DC=COM'
    -ResourceNameSuffix 'avd01'
    -SecurityPrincipalNames 'same@contos.com'
    -SmbServerLocation 'eastus2'
    -StorageAccountPrefix 'streus2'
    -StorageAccountResourceGroupName 'rg-eus2-avd-001'
    -StorageCount 1
    -StorageIndex 0
    -StorageService 'AzureFiles'
    -StorageSuffix 'file.core.windows.net'
    -SubscriptionId '00000000-0000-0000-0000-000000000000'
    -TenantId '00000000-0000-0000-0000-000000000000'
    -UserAssignedIdentityClientId '00000000-0000-0000-0000-000000000000'

This example domain joins an Azure Storage Account to the AVD organizational unit in the Fabrikam.com domain.
#>


param
(
    [Parameter(Mandatory=$false)]
    [String]$ActiveDirectorySolution,

    [Parameter(Mandatory=$false)]
    [String]$DomainAccountType = "ComputerAccount",

    [Parameter(Mandatory)]
    [String]$DomainJoinPassword,

    [Parameter(Mandatory)]
    [String]$DomainJoinUserPrincipalName,

    [Parameter(Mandatory=$false)]
    [String]$Environment,

    [Parameter(Mandatory)]
    [String]$FslogixContainerType,

    [Parameter(Mandatory=$false)]
    [String]$Netbios,

    [Parameter(Mandatory=$false)]
    [String]$OrganizationalUnitPath,

    [Parameter(Mandatory=$false)]
    [String]$ResourceNameSuffix,

    [Parameter(Mandatory)]
    [String]$SecurityPrincipalNames,

    [Parameter(Mandatory=$false)]
    [String]$SmbServerLocation,

    [Parameter(Mandatory=$false)]
    [String]$StorageAccountPrefix,

    [Parameter(Mandatory=$false)]
    [String]$StorageAccountResourceGroupName,

    [Parameter(Mandatory=$false)]
    [Int]$StorageCount,

    [Parameter(Mandatory=$false)]
    [Int]$StorageIndex,

    [Parameter(Mandatory)]
    [String]$StorageService,

    [Parameter(Mandatory=$false)]
    [String]$StorageSuffix,

    [Parameter(Mandatory=$false)]
    [String]$SubscriptionId,

    [Parameter(Mandatory=$false)]
    [String]$TenantId,

    [Parameter(Mandatory=$false)]
    [String]$UserAssignedIdentityClientId
)

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
        New-Item -Path C:\ -Name cse.txt | Out-Null
    }
    $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
    $Entry = '[' + $Timestamp + '] [' + $Type + '] ' + $Message
    $Entry | Out-File -FilePath $Path -Append
}

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

try
{
    ##############################################################
    #  Install Prerequisites
    ##############################################################
    # Install Active Directory PowerShell module
    if($StorageService -eq 'AzureNetAppFiles' -or ($StorageService -eq 'AzureFiles' -and $ActiveDirectorySolution -eq 'ActiveDirectoryDomainServices'))
    {
        $RsatInstalled = (Get-WindowsFeature -Name 'RSAT-AD-PowerShell').Installed
        if(!$RsatInstalled)
        {
            Install-WindowsFeature -Name 'RSAT-AD-PowerShell' | Out-Null
            Write-Log -Message "Installation of the AD module succeeded" -Type 'INFO'
        }
        else
        {
            Write-Log -Message "AD module already exists" -Type 'INFO'
        }
    }


    ##############################################################
    #  Variables
    ##############################################################
    # Convert Security Principal Names from a JSON array to a PowerShell array
    [array]$SecurityPrincipalNames = $SecurityPrincipalNames.Replace("'",'"') | ConvertFrom-Json
    Write-Log -Message "Security Principal Names:" -Type 'INFO'
    $SecurityPrincipalNames | Add-Content -Path 'C:\cse.txt' -Force | Out-Null

    # Selects the appropraite share names based on the FslogixContainerType param from the deployment
    $Shares = switch($FslogixContainerType)
    {
        'CloudCacheProfileContainer' {@('profile-containers')}
        'CloudCacheProfileOfficeContainer' {@('office-containers','profile-containers')}
        'ProfileContainer' {@('profile-containers')}
        'ProfileOfficeContainer' {@('office-containers','profile-containers')}
    }

    if($StorageService -eq 'AzureNetAppFiles' -or ($StorageService -eq 'AzureFiles' -and $ActiveDirectorySolution -eq 'ActiveDirectoryDomainServices'))
    {
        # Create Domain credential
        $DomainUsername = $DomainJoinUserPrincipalName
        $DomainPassword = ConvertTo-SecureString -String $DomainJoinPassword -AsPlainText -Force
        [pscredential]$DomainCredential = New-Object System.Management.Automation.PSCredential ($DomainUsername, $DomainPassword)

        # Get Domain information
        $Domain = Get-ADDomain -Credential $DomainCredential -Current 'LocalComputer'
        Write-Log -Message "Domain information collection succeeded" -Type 'INFO'
    }

    if($StorageService -eq 'AzureFiles')
    {
        $FilesSuffix = '.file.' + $StorageSuffix
        Write-Log -Message "Azure Files Suffix = $FilesSuffix" -Type 'INFO'
    }


    ##############################################################
    #  Process Storage Resources
    ##############################################################
    for($i = 0; $i -lt $StorageCount; $i++)
    {
        # Determine Principal for assignment
        $SecurityPrincipalName = $SecurityPrincipalNames[$i]
        $Group = $Netbios + '\' + $SecurityPrincipalName
        Write-Log -Message "Group for NTFS Permissions = $Group" -Type 'INFO'

        # Get storage resource details
        switch($StorageService)
        {
            'AzureNetAppFiles' {
                $Credential = $DomainCredential
                $SmbServerName = (Get-ADComputer -Filter "Name -like 'anf-$SmbServerLocation*'" -Credential $DomainCredential).Name
                $FileServer = '\\' + $SmbServerName + '.' + $Domain.DNSRoot
            }
            'AzureFiles' {
                $StorageAccountName = $StorageAccountPrefix + ($i + $StorageIndex).ToString().PadLeft(2,'0')
                $FileServer = '\\' + $StorageAccountName + $FilesSuffix

                # Connects to Azure using a User Assigned Managed Identity
                Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId | Out-Null
                Write-Log -Message "Authenticated to Azure" -Type 'INFO'

                # Get the storage account key
                $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName)[0].Value
                Write-Log -Message "The GET operation for the Storage Account key on $StorageAccountName succeeded" -Type 'INFO'

                # Create credential for accessing the storage account
                $StorageUsername = 'Azure\' + $StorageAccountName
                $StoragePassword = ConvertTo-SecureString -String "$($StorageKey)" -AsPlainText -Force
                [pscredential]$StorageKeyCredential = New-Object System.Management.Automation.PSCredential ($StorageUsername, $StoragePassword)
                $Credential = $StorageKeyCredential

                if($ActiveDirectorySolution -eq 'ActiveDirectoryDomainServices')
                {
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
                    $ComputerObject = New-ADComputer -Credential $DomainCredential -Name $StorageAccountName -Path $OrganizationalUnitPath -ServicePrincipalNames $SPN -AccountPassword $ComputerPassword -Description $Description -PassThru
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
                    $DistinguishedName = 'CN=' + $StorageAccountName + ',' + $OrganizationalUnitPath
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
                }
                Disconnect-AzAccount | Out-Null
                Write-Log -Message "Disconnection to Azure succeeded" -Type 'INFO'
            }
        }

        foreach($Share in $Shares)
        {
            # Mount file share
            $FileShare = $FileServer + '\' + $Share
            New-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Root $FileShare -Credential $Credential | Out-Null
            Write-Log -Message "Mounting the Azure file share, $FileShare, succeeded" -Type 'INFO'

            # Set recommended NTFS permissions on the file share
            $ACL = Get-Acl -Path 'Z:'
            $CreatorOwner = New-Object System.Security.Principal.Ntaccount ("Creator Owner")
            $ACL.PurgeAccessRules($CreatorOwner)
            $AuthenticatedUsers = New-Object System.Security.Principal.Ntaccount ("Authenticated Users")
            $ACL.PurgeAccessRules($AuthenticatedUsers)
            $Users = New-Object System.Security.Principal.Ntaccount ("Users")
            $ACL.PurgeAccessRules($Users)
            $DomainUsers = New-Object System.Security.AccessControl.FileSystemAccessRule("$Group","Modify","None","None","Allow")
            $ACL.SetAccessRule($DomainUsers)
            $CreatorOwner = New-Object System.Security.AccessControl.FileSystemAccessRule("Creator Owner","Modify","ContainerInherit,ObjectInherit","InheritOnly","Allow")
            $ACL.AddAccessRule($CreatorOwner)
            $ACL | Set-Acl -Path 'Z:' | Out-Null
            Write-Log -Message "Setting the NTFS permissions on the Azure file share succeeded" -Type 'INFO'

            # Unmount file share
            Remove-PSDrive -Name 'Z' -PSProvider 'FileSystem' -Force | Out-Null
            Start-Sleep -Seconds 5 | Out-Null
            Write-Log -Message "Unmounting the Azure file share, $FileShare, succeeded" -Type 'INFO'
        }
    }
    $Output = [pscustomobject][ordered]@{
        shares = $Shares
    }
    $JsonOutput = $Output | ConvertTo-Json
    return $JsonOutput
}
catch {
    Write-Log -Message $_ -Type 'ERROR'
    $ErrorData = $_ | Select-Object *
    $ErrorData | Out-File -FilePath 'C:\cse.txt' -Append
    throw
}