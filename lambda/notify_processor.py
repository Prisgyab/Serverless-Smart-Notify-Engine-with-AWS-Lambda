"""Handles POST /notify — publishes the event to SNS and logs it to DynamoDB."""

import json
import os
import uuid
from datetime import datetime, timezone

import boto3

sns = boto3.client("sns")
table = boto3.resource("dynamodb").Table(os.environ["NOTIFICATIONS_TABLE"])
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON body"})

    event_type = (body.get("event_type") or "").strip()
    recipient_email = (body.get("recipient_email") or "").strip()
    message = (body.get("message") or "").strip()

    if not event_type or not recipient_email or not message:
        return _response(400, {"error": "event_type, recipient_email, and message are required"})

    notification_id = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()
    status = "sent"

    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"Notification: {event_type}"[:100],
            Message=(
                f"Event: {event_type}\n"
                f"Recipient: {recipient_email}\n"
                f"Message: {message}\n"
                f"Notification ID: {notification_id}"
            ),
            MessageAttributes={
                "event_type": {"DataType": "String", "StringValue": event_type}
            },
        )
    except Exception as exc:  # noqa: BLE001 - record the failure, still respond to the caller
        status = "failed"
        print(f"SNS publish failed for {notification_id}: {exc}")

    table.put_item(
        Item={
            "notification_id": notification_id,
            "timestamp": timestamp,
            "event_type": event_type,
            "recipient_email": recipient_email,
            "message": message,
            "status": status,
        }
    )

    return _response(200, {"notification_id": notification_id, "status": status})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
