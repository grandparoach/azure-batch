#!/bin/bash

### VARIABLES:
STEP="$1"
MOUNT="/mnt/energyplus"


## Creating variables populated with the loop iteration through the manifest file for both weather & IDF files:
WEATHER=$(head -n $STEP /mnt/batch/tasks/shared/manifest.txt | tail -1 | awk '{ print $1 }')
IDF=$(head -n $STEP /mnt/batch/tasks/shared/manifest.txt | tail -1 | awk '{ print $2 }')


### Creating a separate directory for each task's results to be stored in:
RESULTS_DIR="$MOUNT/esim/results/$AZ_BATCH_JOB_ID/$STEP/$AZ_BATCH_TASK_ID"
if [ ! -d $RESULTS_DIR ]
then 
    mkdir -p $RESULTS_DIR
fi


### Running the command:
echo "energyplus -w $MOUNT/inputs/weather/${WEATHER} -d $RESULTS_DIR $MOUNT/esim/models/${IDF}"
energyplus -w $MOUNT/inputs/weather/${WEATHER} -d $RESULTS_DIR $MOUNT/esim/models/${IDF}
