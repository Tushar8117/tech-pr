import boto3
import pymysql
import json
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def read_from_s3(bucket_name, object_key):
    s3 = boto3.client('s3')
    try:
        response = s3.get_object(Bucket=bucket_name, Key=object_key)
        data = json.loads(response['Body'].read())
        print(f"Data read from S3: {data}")
        # Extract 'records' list from the data
        records = data.get('records', [])  # Default to an empty list if 'records' key is missing
        return records
    except Exception as e:
        print(f"Error reading from S3: {str(e)}")
        raise

def validate_data(data):
    if not isinstance(data, list):  # Validate that data is a list
        raise ValueError("Data is not a list")
    for record in data:
        if 'id' not in record or 'name' not in record:
            raise ValueError("Each record must contain 'id' and 'name'")


def write_to_rds(data, rds_endpoint, db_user, db_password, db_name):
    connection = None  # Initialize connection as None
    try:
        logger.info(f"Attempting to connect to RDS at {rds_endpoint}")
        # Establish the connection with timeout
        connection = pymysql.connect(
            host=rds_endpoint,
            user=db_user,
            password=db_password,
            database=db_name,
            port=3306,  # Ensure port is set correctly
            connect_timeout=30 # Optional: Increase timeout if needed
        )
        logger.info("Connected to MySQL RDS successfully.")
        
        try:
            with connection.cursor() as cursor:
                cursor.execute("CREATE TABLE IF NOT EXISTS data (id INT, name VARCHAR(100))")
                query = "INSERT INTO data (id, name) VALUES (%s, %s)"
                for record in data:
                    cursor.execute(query, (record['id'], record['name']))
            connection.commit()
            logger.info("Data written to RDS successfully.")
        except Exception as e:
            logger.error(f"Error executing query: {str(e)}")
            raise
    except Exception as e:
        logger.error(f"Error connecting to RDS: {str(e)}")
        raise
    finally:
        # Ensure the connection is always closed if it was successfully established
        if connection and connection.open:
            connection.close()
            logger.info("Connection closed.")


def lambda_handler(event, context):
    try:
        # Get environment variables
        bucket_name = os.environ['example_bucket_name']
        object_key = os.environ['OBJECT_KEY']
        rds_endpoint = os.environ['RDS_ENDPOINT']
        db_user = os.environ['DB_USER']
        db_password = os.environ['DB_PASSWORD']
        db_name = os.environ['DB_NAME']

        print("Reading data from S3...")
        data = read_from_s3(bucket_name, object_key)
        
        print("Validating data...")
        validate_data(data)
        
        print("Writing data to RDS...")
        write_to_rds(data, rds_endpoint, db_user, db_password, db_name)
    except Exception as e:
        print(f"Error in Lambda function: {str(e)}")
        raise
