"""Handles GET /notifications — returns the full notification history from DynamoDB."""

import json
import os
from decimal import Decimal

import boto3

table = boto3.resource("dynamodb").Table(os.environ["NOTIFICATIONS_TABLE"])


def handler(event, context):
    try:
        items = []
        response = table.scan()
        items.extend(response.get("Items", []))
        while "LastEvaluatedKey" in response:
            response = table.scan(ExclusiveStartKey=response["LastEvaluatedKey"])
            items.extend(response.get("Items", []))
    except Exception as exc:  # noqa: BLE001
        print(f"DynamoDB scan failed: {exc}")
        return _response(500, {"error": "Failed to fetch notifications"})

    items.sort(key=lambda i: i.get("timestamp", ""), reverse=True)

    return _response(200, {"notifications": items})


def _decimal_default(obj):
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, default=_decimal_default),
    }
