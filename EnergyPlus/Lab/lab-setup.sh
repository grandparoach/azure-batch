#!/bin/bash
set -e

BRK() {
# BRK = Break
echo -e "\n\n"
}

LSP() {
# LSP = Log Space
echo -e "\n\n" >> $LOG
}

LABDIR=~/clouddrive/AzureBatch-EnergyPlus-Lab
LOG=$LABDIR/env-setup.log

mkdir $LABDIR
touch $LOG; date >> $LOG

RGNAME="AzureBatch-EnergyPlus-Lab-RG"
UNIQUE_STRING=$(hexdump -e '/1 "%02x"' -n3 < /dev/urandom)
SANAME="azbep$UNIQUE_STRING"
BANAME="azbep$UNIQUE_STRING"

echo -e "\nSetting up the environment for the Azure Batch EnergyPlus Lab"

BRK
az login
BRK

echo -e "\nDownloading and extracting the required input files for the EnergyPlus application: "
wget -O EnergyPlus-inputs.tar.gz https://aka.ms/EnergyPlus-inputs > $LOG
if find . -name "EnergyPlus-inputs.tar.gz" >> /dev/null
then echo -e "Done"
else echo -e "Inputs tarball not found - exiting..."; exit 1
fi

LSP
tar -xvf EnergyPlus-inputs.tar.gz >> $LOG
BRK

echo -e "Adding the Azure Batch CLI Extensions to the local Azure CLI environment. Please press 'y' to complete:  "
az extension add --source https://github.com/Azure/azure-batch-cli-extensions/releases/download/azure-batch-cli-extensions-2.2.2/azure_batch_cli_extensions-2.2.2-py2.py3-none-any.whl
BRK

echo -e "\nHere are all the available Azure regions:\n"

az account list-locations | grep name | awk '{print $2 $3}' | sed 's/.$//' | sed 's/"//g' | sort -d

until [ "$RGLOCVALID" = "true" ]
do
    read -p "Please specify the region to use for this Lab: " REGION
    if [[ $(az account list-locations --query "[*].name" -o tsv | grep -w $REGION) ]]
    then 
	RGLOCVALID="true"
	LSP
	echo "Using $REGION for the Lab environment"
    fi
done
BRK

LSP
az group create --location $REGION --name $RGNAME >> $LOG
echo -e "The Resource Group (RG) name is: $RGNAME"
BRK

LSP
az storage account create --resource-group $RGNAME --name $SANAME --location $REGION --sku Standard_LRS --kind StorageV2 >> $LOG
export AZURE_STORAGE_ACCOUNT=$SANAME
export AZURE_STORAGE_KEY=$(az storage account keys list --account-name $SANAME --resource-group $RGNAME -o table | grep key1 | awk '{print $3}'))

az storage share create --name energyplus --quota 100 >> $LOG
SHARE_ENDPOINT=$(az storage share show --name energyplus -o table | grep endpoint | awk '{print $2}')
az storage container create --name energyplus --public-access blob >> $LOG

#echo -e "A storage account, blob container and file share have all been created for the Lab environment.

The Storage Account (SA) name is: $SANAME
The Blob container name is: energyplus
The File share name is: energyplus"
BRK

LSP
echo -e "Using AzCopy to stage the EnergyPlus input files into the Azure File share:"
azcopy --source EnergyPlus_input_files/ --destination $SHARE_ENDPOINT --dest-key $STORAGE_ACCOUNT_KEY --recursive >> $LOG
echo -e "Done"
BRK

sed -i 's/"{ <<_FILE_SHARE_MOUNT_COMMAND_>> }"/"sudo mount -t cifs //$SANAME.file.core.windows.net/energyplus /mnt/energyplus -o vers=3.0,username=$SANAME,password=$STORAGE_ACCOUNT_KEY,dir_mode=0777,file_mode=0777,sec=ntlmssp"/g' ~/clouddrive/azure-batch/EnergyPlus/Scripts/node-setup.sh

LSP
az storage blob upload-batch --destination energyplus --source ~/clouddrive/azure-batch/EnergyPlus/Scripts/ >> $LOG

export NODE_SETUP_URL=$(az storage blob url --container energyplus --name node-setup.sh)
export BUILD_TASK_URL=$(az storage blob url --container energyplus --name build-task.sh)

LSP
az batch account create --name $BANAME --location $REGION --resource-group $RGNAME --storage-account $SANAME >> $LOG
echo -e "Azure Batch account created: $azbep$UNIQUE_STRING"
BRK
