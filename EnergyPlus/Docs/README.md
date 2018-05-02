Steps to create the workload from the artifacts:

1. 
    Store the 'node-setup.sh' bash shell script as a blob in a storage account container.

2. 
    You will need to update the batch-pool 'blobSource' parameter on whichever pool creation template you wish to use. This parameter property pulls the 'node-setup.sh' script from blob storage onto /mnt/batch/tasks/startup/ on each Batch node that's added to the pool, and assigns read/write/execute permissions for owner, group & world. 
        - Two pool creation templates exist, using either a fixed number of nodes or an AutoScale function.
    
    Remember to amend any additional parameters you feel necessary. The poolId needs to be unique, otherwise the 'az batch pool create' command will fail. 
    
    The maxTasksPerNode and vmSize parameters can be amended to reflect different computational balances.

    There shouldn't need to be any reason to amend the startTask, which invokes 'node-setup.sh' as downloaded from blob storage per Step #1. If you want to add additional steps for nodes during (re)boot, reimaging or (re)provisioning, then either add them to the 'node-setup.sh' script or consider specifying a Job Preparation task.

    ## Creating a pool using the template file:
    You will need the Azure CLI and Azure Batch CLI Extensions module installed.
    
    The syntax is as follows:

    $ az batch pool create \
    --account-name <<_BATCH_ACCOUNT_NAME_>> \
    --account-endpoint <<_BATCH_ACCOUNT_ENDPOINT_>> \
    --account-key <<_BATCH_ACCOUNT_KEY_>> \
    --template /path/to/batch-pool-template.azuredeploy.json
    The behavior of this command has been altered by the following extension: azure_batch_cli_extensions
    You are using an experimental feature {Pool Template}.

3. 
    The 'node-setup.sh' script has a number of steps to prepare nodes for runtime:

        - A "VARIABLES" section exists at the top of the script in case you wish to change any of the environment details.

        - Please ensure the remote filesystem is mounted to /mnt/energyplus, or equivalent (not the root of /mnt or any other special root/base directory).
        
        - The 'manifest.txt' contains details of the weather & model input files.
            : It is required that a file named 'manifest.txt' be placed in the /manifest directory of the mounted filesystem. 
            : This file needs only two fields per line: WEATHER_FILE IDF_FILE
            : There should be as many lines as desired/required to run a whole simulation.
            : Azure Batch TaskFactory will invoke the build-task.sh script on each node with an individual number to parse the manifest.txt file.
            : The 'manifest.txt' file will be copied to the /mnt/batch/tasks/shared directory on each Azure Batch compute node in the pool.
            : The 'manifest.txt' file should not include carriage returns on line endings.
        
        - The 'build-task.sh' file receives the TaskFactory parametric sweep value and stores this in the STEP variable. Weather and model input files are defined using this individual number as parsed from the 'manifest.txt' file.
            : The 'build-task.sh' script will create a separate subdirectory for each task within a results directory in the mounted filesystem. ../esim/results needs to exist. Working on having this tied in with the name of the job as the parent results directory, and each task a subdirectory underneath that. 
            : 'build-task.sh' is pulled from the mounted remote filesystem, under the /software directory, onto each node and stored in /mnt/batch/tasks/shared along with 'manifest.txt'.

            : The 'build-task.sh' script looks for the specified input data in specific locations:
                > $REMOTE_FILESYSTEM_MOUNT_LOCATION/inputs/weather/{WEATHER_FILE}
                > $REMOTE_FILESYSTEM_MOUNT_LOCATION/esim/models/{IDF_FILE}

                The two files (weather & model inputs) included in this artifacts directory are to allow a single simulation to be run as a sample/example. 

                > $REMOTE_FILESYSTEM_MOUNT_LOCATION/esim/results/$TASK_ID/...
                    : No data is required from this directory, but it is storing output files from the simulations.

        - 'energyplus-installer.sh' is the installation script but with a dereferenced name to allow for easier movement between EnergyPlus versions. It's suggested that the official installation script is copied with the name as above. This is hardcoded into scripts, and performs a silent, non-interactive installation.
            : 'energyplus-installer.sh' will also reside in the /software directory, and is installed directly from the mounted remote filesystem using default settings (acceptance of the licence agreement, location of files (/usr/local/EnergyPlus...) and symlink creation).

        - Currently, the schedules files are pulled locally onto each Azure Batch node under the directory /mnt/inputs/schedules. This is to allow the simulations to run, but should be revised to sit within the cohesive remote filesystem data structure hierarchy.

4. 
    TF = TaskFactory
    batch-job-TF-ParametricSweep.azuredeploy.json will identify a pool (through the use of the 'poolId' parameter property) and specify a unique jobId (through the use of the 'jobId' parameter property).

    It may be necessary to amend the start & end parameter set numbers to reflect larger or smaller simulations.
        - Taking the 'manifest.txt' file and running:
            $ cat /mnt/energyplus/manifest/manifest.txt | wc -l
        ...will return the number of lines in the file, and thus what the end property for the parameter set should read. The full path above assumes that the remote filesystem is mounted to /mnt/energyplus

    ## Creating a job using the TaskFactory template file:
    Please ensure the 'poolId' parameter property matches the name of the pool that was created in step #2. If it doesn't, the job will be submitted in a hold state waiting for a pool of that name to exist.
    
    The syntax is as follows:

    $ az batch job create \
    --account-name <<_BATCH_ACCOUNT_NAME_>> \
    --account-endpoint <<_BATCH_ACCOUNT_ENDPOINT_>> \
    --account-key <<_BATCH_ACCOUNT_KEY_>> \
    --template /path/to/batch-job-TaskFactory-template.azuredeploy.json
    The behavior of this command has been altered by the following extension: azure_batch_cli_extensions
    You are using an experimental feature {Job Template}.
    You are using an experimental feature {Task Factory}.

5. 
    Sit back, and review the tasks being submitted to the Azure Batch service, and the simulations running.