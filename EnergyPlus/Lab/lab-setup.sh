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

if ! command -v az >> /dev/null
then 
echo -e "The Azure CLI is not installed - it is required for this script to run.\n\nPlease install it prior to re-running this script\n\n"
exit 1
fi

LABDIR=~/AzureBatch/EnergyPlus-Lab
LOG="${LABDIR}/env-setup.log"

mkdir -p ${LABDIR}
touch $LOG; date >> $LOG

UNIQUE_STRING=$(hexdump -e '/1 "%02x"' -n3 < /dev/urandom) # Random string for naming suffix
RGNAME="AzureBatch-EnergyPlus-Lab-${UNIQUE_STRING}" # Resource Group name
SANAME="azbep${UNIQUE_STRING}" # Storage Account name
BANAME="azbep${UNIQUE_STRING}" # Batch Account name

BRK
echo -e "
#########################################################################
#     SETTING UP THE ENVIRONMENT FOR THE AZURE BATCH ENERGYPLUS LAB     #
#########################################################################
"
BRK

echo "Cloning the GitHub repository for use with the Lab"
if ! command -v git > /dev/null
then 
    if command -v yum >> $LOG; then sudo yum install git >> $LOG
    elif command -v apt-get >> $LOG; then sudo apt-get install git >> $LOG
    elif command -v brew >> $LOG; then brew install git >> $LOG
    fi
fi
git clone https://github.com/whatsondoc/azure-batch.git $LABDIR/azure-batch >> $LOG 2>&1
echo "Done - repository cloned to: $LABDIR"

BRK
echo -e "Performing authentication from the Azure CLI to resources & services:\n"
az login -o table
BRK

echo "Downloading the required input files for the EnergyPlus application from https://aka.ms/EnergyPlus-inputs:"
wget -O ${LABDIR}/EnergyPlus-inputs.tar.gz https://aka.ms/EnergyPlus-inputs >> $LOG 2>&1
if find ${LABDIR} -name "EnergyPlus-inputs.tar.gz" >> /dev/null
then echo -e "Done"
else echo -e "Inputs tarball not found - exiting...\n\n"; exit 1
fi
BRK

LSP
echo "Extracting the tarball to ${LABDIR}:"
tar -xvf ${LABDIR}/EnergyPlus-inputs.tar.gz -C ${LABDIR} >> $LOG
echo "Done"
BRK

echo -e "Adding the Azure Batch CLI Extensions to the local Azure CLI environment:\n "
if ! az extension list -o table | egrep 'cli-extensions|cli_extensions' >> $LOG
then az extension add --source https://github.com/Azure/azure-batch-cli-extensions/releases/download/azure-batch-cli-extensions-2.2.2/azure_batch_cli_extensions-2.2.2-py2.py3-none-any.whl
else echo "Azure Batch CLI Extensions are already installed"
fi
BRK

echo -e "Here are the available Azure regions:\n"
az account list-locations | grep name | awk '{print $2 $3}' | sed 's/.$//' | sed 's/"//g' | sort -d
until [ "$RGLOCVALID" = "true" ]
do
    echo ""
    read -p "Please specify the region to use for this Lab: " REGION
    if [[ $(az account list-locations --query "[*].name" -o tsv | grep -w $REGION) ]]
    then 
	RGLOCVALID="true"
	LSP
	echo -e "\nValid region specified: using $REGION for the Lab environment" 
    fi
done
BRK

LSP
echo "Creating the Resource Group: $RGNAME"
az group create --location $REGION --name $RGNAME >> $LOG
echo -e "Done"
BRK

LSP
echo -e "Creating the necessary Storage resources in the Azure subscription...\n"

echo "Creating a Storage Account:"
az storage account create --resource-group $RGNAME --name $SANAME --location $REGION --sku Standard_LRS --kind StorageV2 >> $LOG
echo -e "Done\n"

echo "Exporting the storage account name & storage account key as variables:"
export AZURE_STORAGE_ACCOUNT=$SANAME
export AZURE_STORAGE_KEY=$(az storage account keys list --account-name $SANAME --resource-group $RGNAME -o table | grep key1 | awk '{print $3}')
echo -e "Done\n"

echo "Creating an Azure Files share:"
az storage share create --name energyplus --quota 100 >> $LOG
export SHARE_ENDPOINT="https://$SANAME.file.core.windows.net/energyplus"
echo -e "Done\n"

echo "Creating a Blob container:"
az storage container create --name energyplus --public-access blob >> $LOG
echo -e "Done"

BRK
echo "A storage account, blob container and file share have all been created for the Lab environment.

The Storage Account (SA) name is: $SANAME
The Blob container name is: energyplus
The File share name is: energyplus"
BRK

LSP
echo "Using AzCopy to stage the EnergyPlus input files into the Azure File share:"
if ! command -v azcopy > /dev/null
then read -p "AzCopy is not installed - holding in case installation will be done in parallel.

Alternatively, hit CTRL+C to cancel this script run. This script will not automatically exit...
"
fi
azcopy --source ${LABDIR}/EnergyPlus_input_files/ --destination ${SHARE_ENDPOINT} --dest-key $AZURE_STORAGE_KEY --recursive >> $LOG
echo -e "Done"
BRK

echo "Updating the node-setup.sh script:"
sed -i "s%FILE_SHARE_MOUNT_COMMAND%sudo mount -t cifs //$SANAME.file.core.windows.net/energyplus /mnt/energyplus -o vers=3.0,username=$SANAME,password=$STORAGE_ACCOUNT_KEY,dir_mode=0777,file_mode=0777,sec=ntlmssp%g" ${LABDIR}/azure-batch/EnergyPlus/Scripts/node-setup.sh
echo "Done"

BRK
LSP
echo "Uploading the scripts to the 'energyplus' blob container:"
az storage blob upload-batch --destination energyplus --source ${LABDIR}/azure-batch/EnergyPlus/Scripts/ >> $LOG 2>&1
echo -e "Done\n"

echo -e "Exporting blob URLs as variables:"
export NODE_SETUP_URL=$(az storage blob url --container energyplus --name node-setup.sh)
export BUILD_TASK_URL=$(az storage blob url --container energyplus --name build-task.sh)
echo "Done.

Setup & configuration files have been uploaded to the 'energyplus' blob container. The blob URLs are as follows:

node-setup.sh: ${NODE_SETUP_URL}
build-task.sh: ${BUILD_TASK_URL}"

BRK

echo "Updating Pool & Job template files in the '${LABDIR}/azure-batch/EnergyPlus/Templates' subdirectories with the above URLs, respectively:"
sed -i "s%<<_URI_FOR_NODE-SETUP.SH_>>%${NODE_SETUP_URL}%g" ${LABDIR}/azure-batch/EnergyPlus/Templates/Pool/batch-pool-MP-fixed.azuredeploy.json
sed -i "s%<<_URI_FOR_BUILD-TASK.SH_>>%${BUILD_TASK_URL}%g" ${LABDIR}/azure-batch/EnergyPlus/Templates/Job/batch-job-TF-ParametricSweep.azuredeploy.json
echo "Done.

This ensures that Azure Batch pulls the 'node-setup.sh' script to nodes joining the Pool, and the 'build-task.sh' script onto each node that will be executing the tasks via the Parametric Sweep."

BRK

LSP
echo "Creating a Batch account: ${BANAME}"
az batch account create --name $BANAME --location $REGION --resource-group $RGNAME --storage-account $SANAME >> $LOG
echo "Done"
BRK

echo "Authenticating to the Azure Batch service using shared key auth"
az batch account login --resource-group $RGNAME --name $BANAME --shared-key
echo "Done"
BRK

LSP
echo "Closing LOG entries - the Lab environment is setup
##################################################

" >> $LOG
echo -e "Environment setup complete.\n\nPlease proceed with Step 2 from the associated Lab guide."
BRK
