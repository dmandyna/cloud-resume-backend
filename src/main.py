import json
import os

import boto3
from botocore.exceptions import ClientError


def get_table_object(table_name: str, hash_key: str, hash_value: str) -> int:
    try:
        response = boto3.client("dynamodb").get_item(TableName=table_name, Key={hash_key: {"S": hash_value}})
    except ClientError as e:
        print("Error message returned by AWS SDK:")
        raise Exception(e.response["Error"]["Message"])
    else:
        try:
            return response["Item"]["count"]["N"]
        except KeyError:
            raise Exception("The DynamoDB entry was found but has invalid content.")


def increase_counter(table_name: str, hash_key: str, hash_value: str, current_counter: int) -> str:
    new_counter = current_counter + 1
    new_counter = str(new_counter)
    print(f"The new counter value is {new_counter}.")
    try:
        boto3.client("dynamodb").update_item(
            TableName=table_name,
            Key={hash_key: {"S": hash_value}},
            UpdateExpression="set #C = :c",
            ExpressionAttributeNames={"#C": "count"},
            ExpressionAttributeValues={":c": {"N": new_counter}},
            ReturnValues="UPDATED_NEW",
        )
        print("The counter value has been successfuly updated.")
    except ClientError as e:
        print("Error message returned by AWS SDK:")
        raise Exception(e.response["Error"]["Message"])
    else:
        return new_counter


def handler(event, context):
    table_name = os.environ["TABLE_NAME"]
    hash_key = os.environ["HASH_KEY"]
    hash_value = os.environ["HASH_VALUE"]

    print("Getting the current visitor counter value...")
    counter_value = int(get_table_object(table_name, hash_key, hash_value))
    print(f"The current counter value is {str(counter_value)}")
    if counter_value:
        new_counter = increase_counter(table_name, hash_key, hash_value, counter_value)
        if new_counter:
            return {
                "statusCode": 200,
                "body": json.dumps(
                    {"message": f"Sucessfully updated the visitor counter.", "newCounter": int(new_counter)}
                ),
                "headers": "application/json",
            }
        else:
            return {
                "statusCode": 500,
                "body": json.dumps({"message": "Unable to update the visitor counter"}),
                "headers": "application/json",
            }
    else:
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Unable to retrieve DynamoDB counter value"}),
            "headers": "application/json",
        }
