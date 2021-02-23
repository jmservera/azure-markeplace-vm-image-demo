#!/bin/sh

resourceGroupName="MARKETPLACEVM"
vmName="marketplacedemo01"
location="northeurope"

az vm stop -g $resourceGroupName -n $vmName
az vm deallocate -g $resourceGroupName -n $vmName

# az disk list to get the diskname

vmDisk=$(az disk list)

az snapshot create -g $resourceGroupName -n vmsnapshot --source $vmDisk

sas=$(az snapshot grant-access --resource-group $resourceGroupName --name $snapshotName --duration-in-seconds $sasExpiryDuration --query [accessSas] -o tsv)



 # create an account

az storage account create -n vmdisksjm01 -g $resourceGroupName --location $location --sku Standard_LRS

az storage container create -n marketplacedisks --account-name vmdisksjm01
