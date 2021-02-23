#!/bin/bash

resourceGroupName="mkttest"
vmName="mkttest"
location="northeurope"
snapshotName="vmsnapshot4"

sasExpiryDuration=3600

#----

storageAccountName="vmdisksjm01"
storageSKU="Standard_LRS"
storageContainerName="marketplacedisks"
destinationVHDFileName="jmimage08.vhd"

echo Deallocating VM

az vm deallocate -g $resourceGroupName -n $vmName
# to get details: az vm show -g $resourceGroupName -n $vmName --show-details -o table

echo Snapshot creation

diskId=$(az vm show -g $resourceGroupName -n $vmName --query storageProfile.osDisk.managedDisk.id -o tsv)
az snapshot create -g $resourceGroupName -n $snapshotName --source $diskId -o table
az snapshot wait --created -g $resourceGroupName -n $snapshotName

echo Get SAS token
sas=$(az snapshot grant-access --resource-group $resourceGroupName --name $snapshotName --duration-in-seconds $sasExpiryDuration --query [accessSas] -o tsv)

# create a storage account

echo Storage account creation

az storage account create -n $storageAccountName -g $resourceGroupName --location $location --sku $storageSKU

az storage container create -n $storageContainerName --account-name $storageAccountName

# az copy
echo Blob copy to new storage account

az storage blob copy start --destination-blob $destinationVHDFileName --destination-container $storageContainerName --account-name $storageAccountName --source-uri $sas

while
    result=$(az storage blob show --container-name $storageContainerName --name $destinationVHDFileName --account-name $storageAccountName --query properties.copy.[status,progress] -o tsv 2>/dev/null)
    readarray completionResult <<< $result

    echo -n " ${completionResult[1]::-1} " $'\r'
    [ ${completionResult[0]} != 'success' ]
do true; done

echo Done copying