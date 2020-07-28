#!/bin/bash
set -e

### VARIABLES:
MOUNT="/mnt/energyplus"
MANIFEST="manifest.txt"
BUILD_TASK="build-task.sh"
NODE_DIR="/mnt/batch/tasks/shared"
ENERGY_INSTALLER="energyplus-installer.sh"


### Enabling Application Insights
apt-get update
apt-get -y install python-dev python-pip
pip install --upgrade pip
pip install psutil python-dateutil applicationinsights
wget --no-cache https://raw.githubusercontent.com/Azure/batch-insights/master/nodestats.py
python --version
python nodestats.py > node-stats.log 2>&1 &

### Make a directory for the remote file share mount (unless it already exists):
if [ ! -d $MOUNT ]
then
    sudo mkdir $MOUNT
fi

### Mount the remote filesystem to $MOUNT specified above:

if [ ! -d "/etc/smbcredentials" ]; then
sudo mkdir /etc/smbcredentials
fi
if [ ! -f "/etc/smbcredentials/<<SANAME>>.cred" ]; then
    sudo bash -c 'echo "username=<<SANAME>>" >> /etc/smbcredentials/<<SANAME>>.cred'
    sudo bash -c 'echo "password=<<SAKEY>> >> /etc/smbcredentials/<<SANAME>>.cred'
fi
sudo chmod 600 /etc/smbcredentials/<<SANAME>>.cred

sudo mount -t cifs //<<SANAME>>.file.core.windows.net/energyplus /mnt/energyplus -o vers=3.0,credentials=/etc/smbcredentials/<<SANAME>>.cred,dir_mode=0777,file_mode=0777,serverino

### Install EnergyPlus software from remote filesystem if the command 'energyplus' doesn't exist:
if ! command -v energyplus >> /dev/null
then
    if [ ! -f $MOUNT/EnergyPlus_input_files/software/${ENERGY_INSTALLER} ]
    then
        echo "Downloading EnergyPlus v8.5.0 because 'energyplus-installer.sh' is not present in the software directory:"
        wget -O $MOUNT/EnergyPlus_input_files/software/${ENERGY_INSTALLER} https://github.com/NREL/EnergyPlus/releases/download/v8.5.0/EnergyPlus-8.5.0-c87e61b44b-Linux-x86_64.sh
    fi
## Adding executable permissions to $ENERGYINSTALLER (have opted for a simplified name to reduce script administration when moving between EnergyPlus versions):
chmod +x $MOUNT/EnergyPlus_input_files/software/${ENERGY_INSTALLER}
## Invoking the EnergyPlus installation script non-interactively:
$MOUNT/EnergyPlus_input_files/software/${ENERGY_INSTALLER} << EOI
y


EOI
fi

### Copying the $BUILDTASK script & $MANIFEST file to the local Batch tasks shared directory for execution via TaskFactory:
#if [ ! -f $NODE_DIR/$BUILD_TASK ]
#then
#    cp $MOUNT/software/$BUILD_TASK $NODE_DIR/
#        if [ -f $NODE_DIR/$BUILD_TASK ]
#        then
#            echo "Our $BUILD_TASK execution script is here:"
#            ls -lh $NODE_DIR | grep $BUILD_TASK 
#        else
#            echo "Our $BUILD_TASK execution script is not here - terminating..."
#            exit 1
#        fi
#fi

### Copying the $MANIFEST file to the local Batch tasks shared directory for execution via TaskFactory:
cp $MOUNT/EnergyPlus_input_files/manifest/$MANIFEST $NODE_DIR/
if [ -f $NODE_DIR/$MANIFEST ]
then
    echo "Our $MANIFEST file is here:"
    ls -lh $NODE_DIR | grep $MANIFEST
else
    echo "Our $MANIFEST file is not here - terminating..."
    exit 1
fi

### TEMPORARY: Copying schedules files locally to maintain expected file path:
if [ ! -d /mnt/inputs/schedules ]
then
    mkdir -p /mnt/inputs/schedules
    cp /mnt/energyplus/EnergyPlus_input_files/inputs/schedules/* /mnt/inputs/schedules
fi
    echo "The schedules files present on this node:"
    find /mnt/inputs/schedules/ -name "*.csv" -exec ls -lh {} \;
### TEMPORARY:::
