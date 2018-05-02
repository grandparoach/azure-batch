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
pip install psutil python-dateutil applicationinsights
wget --no-cache https://raw.githubusercontent.com/Azure/batch-insights/master/nodestats.py
python --version
python nodestats.py > node-stats.log 2>&1 &

### Make a directory for the remote file share mount (unless it already exists):
if [ ! -d $MOUNT ]
then
    mkdir $MOUNT
fi

### Mount the remote filesystem to $MOUNT specified above:
"{ <<_FILE_SHARE_MOUNT_COMMAND_>> }"

### Install EnergyPlus software from remote filesystem if the command 'energyplus' doesn't exist:
if ! command -v energyplus >> /dev/null
then
## Adding executable permissions to $ENERGYINSTALLER (have opted for a simplified name to reduce script administration when moving between EnergyPlus versions):
chmod +x $MOUNT/software/${ENERGY_INSTALLER}
## Invoking the EnergyPlus installation script non-interactively:
$MOUNT/software/${ENERGY_INSTALLER} << EOI
y


EOI
fi

### Copying the $BUILDTASK script & $MANIFEST file to the local Batch tasks shared directory for execution via TaskFactory:
if [ ! -f $NODE_DIR/$BUILD_TASK ]
then
    cp $MOUNT/software/$BUILD_TASK $NODE_DIR/
        if [ -f $NODE_DIR/$BUILD_TASK ]
        then
            echo "Our $BUILD_TASK execution script is here:"
            ls -lh $NODE_DIR | grep $BUILD_TASK 
        else
            echo "Our $BUILD_TASK execution script is not here - terminating..."
            exit 1
        fi
fi

cp $MOUNT/manifest/$MANIFEST $NODE_DIR/
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
    cp /mnt/energyplus/inputs/schedules/* /mnt/inputs/schedules
    echo "The schedules files present on this node:"
    find /mnt/inputs/schedules/ -name "*.csv" -exec ls -lh {} \;
fi
### TEMPORARY:::