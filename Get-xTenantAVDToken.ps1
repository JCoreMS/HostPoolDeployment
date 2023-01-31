
###################################################################
# FUNCTION: Connect and select Azure Sub, RG and Host Pools Function
###################################################################
Function Get-AVDHostPoolInfo ($cloud) {
    Clear-Host
    Write-host "Connect and Authenticate to $cloud. (Look for minimized Window!)" -ForegroundColor Cyan
    Connect-AzAccount -Environment $cloud
    Write-Host "Getting List of Subscriptions..." -ForegroundColor Cyan
    $Subs = Get-AzSubscription | Sort-Object -Property Name
    If ($Subs.count -ne 1) {
        $i = 1
        Foreach ($Sub in $Subs) {
            Write-Host $i "-" $Sub.Name
            $i ++
        }
        $Environment = Read-Host "Select $cloud Subscription"
        $Environment = $Subs[$Environment - 1]
    } 
    Else {
        Write-Host "Only one Subscription found: " $Subs -ForegroundColor Yellow
        $Environment = $Subs
    }

    # Resource Groups
    Clear-Host
    Write-Host "Getting List of Resource Groups..." -ForegroundColor Cyan
    Set-AzContext -SubscriptionObject $Environment | Out-Null
    $RGs = Get-AzResourceGroup | Sort-Object -Property ResourceGroupName
    If ($RGs.count -ne 1) {
        $i = 1
        Foreach ($RG in $RGs) {
            Write-Host $i "-" $RG.resourcegroupname
            $i ++
        }
        $ResourceGroup = Read-Host "Select $cloud Resource Group with Host Pool resources"
        $ResourceGroup = $RGs[$ResourceGroup - 1]
    }
    Else {
        Write-Host "Only one Resource Group found: " $RGs -ForegroundColor Yellow
        $ResourceGroup = $RGs
    }

    # Host Pools
    Clear-Host
    Write-Host "Getting List of Host Pools..." -ForegroundColor Cyan
    $HPs = Get-AzWvdHostPool -DefaultProfile $Sub | Sort-Object -Property Name
    If ($HPs.count -ne 1) {
        $i = 1
        Foreach ($HP in $HPs) {
            Write-Host $i "-" $HP.Name
            $i ++
        }
        $HostPool = Read-Host "Select $cloud Host Pool"
        $HostPool = $HPs[$HostPool - 1]
    }
    Else {
        Write-Host "Only one Host Pool found: " $HPs -ForegroundColor Yellow
        $HostPool = $HPs
    }

    $AVDInfo = [PSCustomObject]@{
        SubName = $Environment.Name
        SubId = $Environment.Id
        ResourceGroup = $ResourceGroup.ResourceGroupName
        HostPool = $HostPool.Name
    }
    
    Return $AVDInfo

}


#################################
#Step 1 - Connect to Target Environment and acquire Host Pool Token
#################################

# Get target Cloud
$response = Read-Host "Are you needing to connect to a Soveriegn Cloud? (Y or N)"
If($response.ToUpper() -eq 'Y'){
    Write-Host "Select a cloud to connect to:"
    Write-Host "1 - Azure US Government"
    Write-Host "2 - Azure China"
    Write-Host "3 - Azure Germany"
    $selection = Read-Host "Select a number"
    switch ($selection) {
        1 {$TargetCloud = 'AzureUSGovernment'}
        2 {$TargetCloud = 'AzureChinaCloud'}
        3 {$TargetCloud = 'AzureGermanCloud'}
        Default {$TargetCloud = "AzureUSGovernment"}
    }
}
else {$TargetCloud = 'AzureCloud'}
# Get host pool information from function
$HostPoolTargetInfo = Get-AVDHostPoolInfo -cloud $TargetCloud
Write-Host "Getting Host Pool Registration Token..." -ForegroundColor Green
$TargetPool = Get-AzWvdRegistrationInfo -ResourceGroupName $HostPoolTargetInfo.ResourceGroup -HostPoolName $HostPoolTargetInfo.HostPool
If ($TargetPool.Token -eq $null){
    Write-Host "No Host Pool Registration Token found, creating one...(valid for 24hrs)"
    $RegistrationInfo = New-AzWvdRegistrationInfo -ResourceGroupName $HostPoolTargetInfo.ResourceGroup -HostPoolName $HostPoolTargetInfo.HostPool -ExpirationTime (Get-Date).AddDays(1)
    $Token = $RegistrationInfo.Token
}
else {$Token = $TargetPool.Token}
Set-Clipboard -Value $Token
Write-Host "Below is the Registration Token needed for $TargetCloud and has been saved to your clipboard!`n"
$Token