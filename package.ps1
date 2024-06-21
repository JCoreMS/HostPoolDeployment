

$pkgstorageparms = @{
  ResourceGroupName = "rg-eus2-AVDLab-Storage"
  Name = "storeus2packages02"
  Location = "eastus2"
  SkuName = "Standard_LRS"
  Kind = "StorageV2"
  MinimumTlsVersion = "TLS1_2"
  AllowBlobPublicAccess = $true
  AllowSharedKeyAccess = $false
}

$pkgstorageaccount = New-AzStorageAccount @pkgstorageparms

$pkgstoragecontext = New-AzStorageContext -StorageAccountName $pkgstorageaccount.StorageAccountName -UseConnectedAccount

New-AzStorageContainer -Name appcontainer -Context $pkgstoragecontext -Permission blob

$blobparms = @{
  File = "app.zip"
  Container = "appcontainer"
  Blob = "app.zip"
  Context = $pkgstoragecontext
}

Set-AzStorageBlobContent @blobparms

$packageuri = (Get-AzStorageBlob -Container appcontainer -Blob app.zip -Context $pkgstoragecontext).ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri

Get-AzManagedApplicationDefinition -ResourceGroupName "rg-eus2-AVDLab-Storage"