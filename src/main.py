import json
import os
from datetime import datetime, timedelta

import boto3
from botocore.exceptions import ClientError

counter_table_name = os.environ["COUNTER_TABLE_NAME"]
counter_hash_key = os.environ["COUNTER_HASH_KEY"]
counter_hash_value = os.environ["COUNTER_HASH_VALUE"]
tracker_table_name = os.environ["TRACKER_TABLE_NAME"]
tracker_hash_key = os.environ["TRACKER_HASH_KEY"]


def get_counter_value() -> int:
    try:
        response = boto3.client("dynamodb").get_item(
            TableName=counter_table_name, Key={counter_hash_key: {"S": counter_hash_value}}
        )
    except ClientError as e:
        print("Error message returned by AWS SDK:")
        raise Exception(e.response["Error"]["Message"])
    else:
        try:
            return int(response["Item"]["count"]["N"])
        except KeyError:
            raise Exception("The DynamoDB entry was found but has invalid content.")


def increase_counter(current_counter: int) -> str:
    new_counter = current_counter + 1
    new_counter = str(new_counter)
    print(f"The new counter value is {new_counter}.\n")
    try:
        boto3.client("dynamodb").update_item(
            TableName=counter_table_name,
            Key={counter_hash_key: {"S": counter_hash_value}},
            UpdateExpression="set #C = :c",
            ExpressionAttributeNames={"#C": "count"},
            ExpressionAttributeValues={":c": {"N": new_counter}},
            ReturnValues="UPDATED_NEW",
        )
        print("The counter value has been successfully updated.\n")
    except ClientError as e:
        print("Error message returned by AWS SDK:")
        raise Exception(e.response["Error"]["Message"])
    else:
        return new_counter


def update_visitor_tracker(source_ip: str) -> bool:
    # This function will only update tracker table if there
    # was no traffic from that source IP in 30 days

    try:
        response = boto3.client("dynamodb").get_item(
            TableName=tracker_table_name, Key={tracker_hash_key: {"S": source_ip}}
        )
    except ClientError as e:
        print(f"DynamoDB returned an exception: {e}")

    if not response.get("Item"):
        epoch_in_30d = int((datetime.now() + timedelta(days=30)).timestamp() * 1000)
        try:
            response = boto3.client("dynamodb").put_item(
                TableName=tracker_table_name,
                Item={tracker_hash_key: {"S": source_ip}, "expiry_date": {"N": str(epoch_in_30d)}},
            )
            return True
        except ClientError as e:
            print(f"DynamoDB returned an exception: {e}")
    return False


def handler(event, context):
    print("Getting the current visitor counter value... \n")
    counter_value = get_counter_value()
    print(f"The current counter value is {str(counter_value)}\n")

    if counter_value or counter_value == 0:
        if not event == {}:
            if not update_visitor_tracker(event["requestContext"]["identity"]["sourceIp"]):
                return {
                    "statusCode": 200,
                    "body": json.dumps(
                        {
                            "message": "This user already visited the page in the last 30 days.",
                            "currentCounter": counter_value,
                        }
                    ),
                    "headers": "application/json",
                }

        new_counter = increase_counter(counter_value)
        if new_counter:
            return {
                "statusCode": 200,
                "body": json.dumps(
                    {
                        "message": f"Sucessfully updated the visitor counter.",
                        "currentCounter": int(new_counter),
                        "oldCounter": counter_value,
                    }
                ),
                "headers": "application/json",
            }
        else:
            return {
                "statusCode": 500,
                "body": json.dumps(
                    {"message": "Unable to update the visitor counter", "currentCounter": counter_value}
                ),
                "headers": "application/json",
            }
    else:
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Unable to retrieve DynamoDB counter value"}),
            "headers": "application/json",
        }
