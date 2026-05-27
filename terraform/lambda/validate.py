import json


def handler(event, context):
    print("Validating data...")
    print(f"Input: {json.dumps(event)}")
    return {
        "statusCode": 200,
        "status": "validated",
        "input": event,
    }
