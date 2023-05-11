import os
import time
import json
import base64
import logging

from google.cloud import storage
from google.cloud import bigquery
from google.cloud import workflows_v1beta
from google.cloud.workflows import executions_v1beta
from google.cloud.workflows.executions_v1beta.types import executions

logger = logging.getLogger("cf_dispatch_logs")


def receive_messages(event: dict, context: dict):
    """
    Triggered from a message on a Cloud Pub/Sub topic.
    Inserts a file into the correct BigQuery raw table. If succeeded then
    archive the file and trigger the Cloud Workflow pipeline else move the
    file to the reject/ subfolder.

    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """

    logger.debug("---------- receiving messages ----------")

    # rename the variable to be more specific and write it to the logs
    pubsub_event = event
    logger.info(pubsub_event)

    # decode the data giving the targeted table name
    table_name = base64.b64decode(pubsub_event['data']).decode('utf-8')

    # get the blob infos from the attributes
    bucket_name = pubsub_event['attributes']['bucket_name']
    blob_path = pubsub_event['attributes']['blob_path']

    load_completed = False
    try:
        # insert the data into the raw table then archive the file
        insert_into_raw(table_name, bucket_name, blob_path)
        move_file(bucket_name, blob_path, 'archive')
        load_completed = True
        logger.info("Inserted data into bigquery")

    except Exception as e:
        logger.warning(e)
        move_file(bucket_name, blob_path, 'reject')

    # trigger the pipeline if the load is completed
    if load_completed:
        trigger_worflow(table_name)
        logger.info("Trigger the pipeline after inserting data")


def insert_into_raw(table_name: str, bucket_name: str, blob_path: str):
    """
    Insert a file into the correct BigQuery raw table.

    Args:
         table_name (str): BigQuery raw table name.
         bucket_name (str): Bucket name of the file.
         blob_path (str): Path of the blob inside the bucket.
    """

    # connect to the Cloud Storage client
    storage_client = storage.Client()

    # get the util bucket object using the os environments
    project_id = os.environ['GCP_PROJECT']
    # bucket = storage_client.bucket(f"{project_id}_{os.environ['UTIL_BUCKET_SUFFIX']}")
    bucket = storage_client.bucket(f"{project_id}_magasin_cie_utils")

    # loads the schema of the table as a json (dictionary) from the bucket
    source_blob = bucket.blob(f"schemas/raw/{table_name}.json")
    content_bucket = source_blob.download_as_string().decode("utf-8")
    table_schema = json.loads(content_bucket)
    logger.info("Successfully loaded the schema")

    # store in a string variable the blob uri path of the data to load (gs://your-bucket/your/path/to/data)
    blob_uri = f"gs://{bucket_name}/{blob_path}"

    # connect to the BigQuery Client
    bq_client = bigquery.Client(project_id)

    # store in a string variable the table id with the bigquery client. (project_id.dataset_id.table_name)
    table = bq_client.get_dataset("raw")
    dataset_id = table.dataset_id
    table_id = f"{project_id}.{dataset_id}.{table_name}"

    # create your LoadJobConfig object from the BigQuery library
    # find config based on file extension
    try:
        file_extension = blob_path.split('.')[-1].lower()
    except:
        raise Exception(f"Cannot find file extension for {blob_path}")

    if file_extension == "csv":
        logger.debug("Ingest csv file")
        job_config = bigquery.LoadJobConfig(
            schema=table_schema,
            skip_leading_rows=1,
            source_format=bigquery.SourceFormat.CSV,
        )
    elif file_extension == "json":
        logger.debug("Ingest json file")
        job_config = bigquery.LoadJobConfig(
            schema=table_schema,
            source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        )
    else:
        raise Exception(f"Invalid extension {file_extension}")

    logger.info("Created load job config")

    # and run your loading job from the blob uri to the destination raw table
    try:
        load_job = bq_client.load_table_from_uri(
            blob_uri, table_id, job_config=job_config)  # Make an API request.
        logger.info("Running job")
    except Exception as e:
        logger.warning(f"Cannot load blob : {e}")

    # waits the job to finish and print the number of rows inserted
    load_job.result()
    destination_table = bq_client.get_table(table_id)
    logger.info(f"Loaded {destination_table.num_rows}")
    pass


def trigger_worflow(table_name: str):
    """
    Triggers and waits for a `<table_name>_wkf` Workflows pipeline's result within the project ID.

    Args:
         table_name (str): BigQuery raw table name.
    """

    # check : https://cloud.google.com/workflows/docs/executing-workflow
    project = os.environ['GCP_PROJECT']
    # location = os.environ['WKF_LOCATION']
    location = 'europe-west1'
    workflow = f'{table_name}_wkf'

    # trigger a Cloud Workflows execution according to the table updated
    execution_client = executions_v1beta.ExecutionsClient()
    workflows_client = workflows_v1beta.WorkflowsClient()

    # Construct the fully qualified location path.
    parent = workflows_client.workflow_path(project, location, workflow)

    # Execute the workflow.
    response = execution_client.create_execution(request={"parent": parent})
    logger.info(f"Created execution: {response.name}")

    # wait for the result (with exponential backoff delay will be better)
    execution_finished = False
    backoff_delay = 1  # Start wait with delay of 1 second
    logger.info('Poll every second for result...')
    while (not execution_finished):
        execution = execution_client.get_execution(
            request={"name": response.name})
        execution_finished = execution.state != executions.Execution.State.ACTIVE

        # If we haven't seen the result yet, wait a second.
        if not execution_finished:
            logger.info('- Waiting for results...')
            time.sleep(backoff_delay)
            backoff_delay *= 2  # Double the delay to provide exponential backoff.
        else:
            logger.info(
                f'Execution finished with state: {execution.state.name}')
            logger.info(execution.result)
            return execution.result

    # be verbose where you think you have to

    raise NotImplementedError()


def move_file(bucket_name, blob_path, new_subfolder):
    """
    Move a file a to new subfolder as root.

    Args:
         bucket_name (str): Bucket name of the file.
         blob_path (str): Path of the blob inside the bucket.
         new_subfolder (str): Subfolder where to move the file.
    """

    # TODO: 1
    # Now you are confortable with the first Cloud Function you wrote.
    # Inspire youreslf from this first Cloud Function and:
    # connect to the Cloud Storage client
    storage_client = storage.Client()

    # get the bucket object and the blob object
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(blob_path)

    # split the blob path to isolate the file name
    # create your new blob path with the correct new subfolder given from the arguments
    current_subfolder = os.path.dirname(blob_path)
    new_blob_path = blob_path.replace(current_subfolder, new_subfolder)

    # move your file inside the bucket to its destination
    new_blob = bucket.copy_blob(blob, bucket, new_blob_path)
    bucket.delete_blob(blob.name)

    # print the actual move you made
    # See documentation
    logger.info(
        f"Blob {blob.name} in bucket {bucket.name} moved to blob {new_blob.name} in bucket {bucket.name}."
    )

    logger.info(f'{blob_path} moved to {new_blob_path}')


if __name__ == '__main__':
    # here you can test with mock data the function in your local machine
    # it will have no impact on the Cloud Function when deployed.

    project_id = 'sandbox-sdiouf'
    data = base64.b64encode('store'.encode('utf-8'))

    # test your Cloud Function for the store file.
    mock_event = {
        'data': data,
        'attributes': {
            'bucket': f'{project_id}_magasin_cie_landing',
            'file_path': os.path.join('input', 'store_20220531.csv'),
        }
    }

    mock_context = {}
    receive_messages(mock_event, mock_context)
