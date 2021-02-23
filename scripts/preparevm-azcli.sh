#!/bin/sh

resourceGroupName="mkttest"
vmName="mkttest"
location="northeurope"
snapshotName="vmsnapshot"

sasExpiryDuration=3600

az vm deallocate -g $resourceGroupName -n $vmName
# to get details: az vm show -g $resourceGroupName -n $vmName --show-details -o table


# az disk list to get the diskname

diskId=$(az vm show -g $resourceGroupName -n $vmName --query storageProfile.osDisk.managedDisk.id -o tsv)
az snapshot create -g $resourceGroupName -n $snapshotName --source $diskId
az snapshot wait --created -g $resourceGroupName -n $snapshotName

sas=$(az snapshot grant-access --resource-group $resourceGroupName --name $snapshotName --duration-in-seconds $sasExpiryDuration --query [accessSas] -o tsv)



 # create an account

az storage account create -n vmdisksjm01 -g $resourceGroupName --location $location --sku Standard_LRS

az storage container create -n marketplacedisks --account-name vmdisksjm01

# TODO az copy