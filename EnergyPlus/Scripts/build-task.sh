#!/bin/bash

### VARIABLES:
STEP="$1"
MOUNT="/mnt/energyplus"

## Creating variables populated with the loop iteration through the manifest file for both weather & IDF files:
WEATHER=$(head -n $STEP /mnt/batch/tasks/shared/manifest.txt | tail -1 | awk '{ print $1 }')
IDF=$(head -n $STEP /mnt/batch/tasks/shared/manifest.txt | tail -1 | awk '{ print $2 }')

### Creating a separate directory for each task's results to be stored in:
if [ ! -d $MOUNT/esim/results/$STEP ]
then 
    mkdir $MOUNT/esim/results/$STEP
fi

### Running the command:
echo "energyplus -w $MOUNT/inputs/weather/${WEATHER} -d $MOUNT/esim/results/$STEP $MOUNT/esim/models/${IDF}"
energyplus -w $MOUNT/inputs/weather/${WEATHER} -d $MOUNT/esim/results/$STEP $MOUNT/esim/models/${IDF}