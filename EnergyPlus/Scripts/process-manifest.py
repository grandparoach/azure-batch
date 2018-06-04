#! /usr/bin/env python
import os
import sys

from azure.batch import BatchServiceClient
from azure.batch import models
from azure.batch.batch_auth import SharedKeyCredentials
from azure.common.credentials import BasicTokenAuthentication
from azure.common.credentials import OAuthTokenAuthentication

def main():
    print("------------------------------------")
    print("Azure Batch Task Manager task reporting for duty")

    job_id = os.environ["AZ_BATCH_JOB_ID"]
    batch_account_url = os.environ["AZ_BATCH_ACCOUNT_URL"]
    manifest_file = os.environ["AZ_BATCH_TASK_WORKING_DIR"] + "/assets/manifest.txt"
    tasks = []
    counter = 1

    # Create Batch client
    # When running inside a task with authentication enabled, this token allows access to the rest of the job
    #credentials = BasicTokenAuthentication(os.environ["AZ_BATCH_AUTHENTICATION_TOKEN"])
    #credentials = SharedKeyCredentials("<your account name>", "<your account key>")
    credentials = OAuthTokenAuthentication(
        client_id=None,
        token={ "access_token" : os.environ["AZ_BATCH_AUTHENTICATION_TOKEN"] }
    )
    batch_client = BatchServiceClient(credentials, base_url=batch_account_url)

    print("opening file: {0}".format(manifest_file))
    with open(manifest_file) as manifest:
        for line in manifest:
            print("create task for: " + line)
            tasks.append(create_task(counter, line))
            counter += 1

    # submit the tasks to the service
    submit_tasks(batch_client, job_id, tasks)


def submit_tasks(batch_client, job_id, tasks):
    print("submitting: {0} tasks to job: {1}".format(str(len(tasks)), job_id))
    for task in tasks:
        batch_client.task.add(job_id = job_id, task = task)


def create_task(id, command_line):
    return models.TaskAddParameter(id=id, command_line="/bin/bash -c 'echo " + command_line + "'")


if __name__ == '__main__':
    main()
