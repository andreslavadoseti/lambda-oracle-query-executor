import cx_Oracle as driver
import boto3
import base64
from botocore.exceptions import ClientError
import logging
import json

def lambda_handler(event, context):
    query=event['query']
    secret_name=event['secret_name']
    secret=get_secret(secret_name)
    dsn_tns = driver.makedsn(secret['host'], secret['port'], secret['dbname'])
    connection = driver.connect(secret['username'], secret['password'], dsn_tns)
    db_version=connection.version
    cursor = connection.cursor()
    data = []
    col_names = []
    try:
        rows = cursor.execute(query).fetchall()
        col_names = [row[0] for row in cursor.description]
        for row in rows:
            rowData = {}
            for i in range(0, len(col_names)):
                rowData[col_names[i]] = row[i]
            data.append(rowData)
    except Exception as e:
        logging.error('Query error: {}'.format(str(e)))
        raise e
    finally:
        connection.close()
    return {
        'statusCode': 200,
        'connection_data': {
            'db_engine': secret['engine'],
            'db_version': db_version,
            'rds_identifier': secret['dbInstanceIdentifier'],
            'db_host': secret['host'],
            'db_name': secret['dbname']
        },
        'resultset': {
            'column_names': col_names,
            'data': data
        }
    }

def get_secret(secret_name):
    # Create a Secrets Manager client
    client = boto3.client('secretsmanager')
    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'DecryptionFailureException':
            # Secrets Manager can't decrypt the protected secret text using the provided KMS key.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InternalServiceErrorException':
            # An error occurred on the server side.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            # You provided an invalid value for a parameter.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            # You provided a parameter value that is not valid for the current state of the resource.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'ResourceNotFoundException':
            # We can't find the resource that you asked for.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
    else:
        # Decrypts secret using the associated KMS CMK.
        # Depending on whether the secret is a string or binary, one of these fields will be populated.
        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
        else:
            secret = base64.b64decode(get_secret_value_response['SecretBinary'])
    return json.loads(secret)