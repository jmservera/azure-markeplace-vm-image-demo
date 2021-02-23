#!/bin/bash

resourceGroupName="jmtest01_group"
vmName="jmtest01"
location="northeurope"
snapshotName="vmsnapshot02"

sasExpiryDuration=3600

#----

storageAccountName="vmdisksjm01"
storageSKU="Standard_LRS"
storageContainerName="marketplacedisks"
destinationVHDFileName="jmimage02.vhd"

#----

testRG="${resourceGroupName}_test"
testVmName="${vmName}02"


echo "Deallocating VM, this is needed in order to stop and create a snapshot"
az vm deallocate -g $resourceGroupName -n $vmName


echo "Snapshot creation, from the snapshot we will then create a copy in our storage"
diskId=$(az vm show -g $resourceGroupName -n $vmName --query storageProfile.osDisk.managedDisk.id -o tsv)
az snapshot create -g $resourceGroupName -n $snapshotName --source $diskId -o table
az snapshot wait --created -g $resourceGroupName -n $snapshotName


echo "Get SAS token, needed for reading the copy"
sas=$(az snapshot grant-access --resource-group $resourceGroupName --name $snapshotName --duration-in-seconds $sasExpiryDuration --query [accessSas] -o tsv)


echo "Storage account creation to write the vhd copy"
az storage account create -n $storageAccountName -g $resourceGroupName --location $location --sku $storageSKU
az storage container create -n $storageContainerName --account-name $storageAccountName


echo "Copy the vhd into a blob in the new storage account"
az storage blob copy start --destination-blob $destinationVHDFileName --destination-container $storageContainerName --account-name $storageAccountName --source-uri $sas

# wait until the copy is finished
while
    result=$(az storage blob show --container-name $storageContainerName --name $destinationVHDFileName --account-name $storageAccountName --query properties.copy.[status,progress] -o tsv 2>/dev/null)
    readarray completionResult <<< $result

    echo -n " ${completionResult[1]::-1} " $'\r'
    [ ${completionResult[0]} != 'success' ]
do true; done


# echo "Generating sas token for the copied vhd"
# end=$(date -u -d "+3 hours" '+%Y-%m-%dT%H:%MZ')
# vhdsas=$(az storage blob generate-sas --account-name $storageAccountName --container-name $storageContainerName --name $destinationVHDFileName --permissions r --expiry $end --https-only -o tsv)

echo "Done copying, extracting the URI for the vhd"
vhduri=$(az storage blob url --account-name $storageAccountName --container-name $storageContainerName --name $destinationVHDFileName -o tsv)
echo "Access uri: $vhduri"

echo "Generate a test deployment to check our VM works"
az group create -n $testRG -l $location
vmurl=$(az deployment group create -g $testRG --template-file ../template/customvm.json --parameters "{ \"sourceImageVhdUri\": {\"value\": \"$vhduri\"}, \"vmName\": {\"value\": \"${testVmName}\"}}" --query properties.outputs.fqdn.value -o tsv)

echo "Deployment finished. Checking $vmurl output"
curl http://$vmurl:8000