import json


def handler(event, context):
    print("Logging metrics...")
    print(f"Input: {json.dumps(event)}")
    return {
        "statusCode": 200,
        "status": "logged",
        "input": event,
    }
