import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm = boto3.client("ssm")
cloudwatch = boto3.client("cloudwatch")

CLUSTER_NAME = os.environ["CLUSTER_NAME"]
SSM_ADVICE_KEY = os.environ["SSM_ADVICE_KEY"]


def handler(event: dict, context) -> dict:
    logger.info("Received event: %s", json.dumps(event))

    detail = event.get("detail", {})
    alarm_name = detail.get("alarmName", "")
    new_state = detail.get("state", {}).get("value", "")

    if new_state != "ALARM":
        logger.info("Alarm %s transitioned to %s — not actionable", alarm_name, new_state)
        return {"statusCode": 200, "body": "skipped"}

    advice = _build_advice(alarm_name, detail)
    _write_advice(alarm_name, advice)

    return {"statusCode": 200, "body": f"advice written for alarm {alarm_name}"}


def _build_advice(alarm_name: str, detail: dict) -> dict:
    reason = detail.get("state", {}).get("reason", "")
    return {
        "cluster": CLUSTER_NAME,
        "alarm": alarm_name,
        "recommendation": "scale_out",
        "reason": reason,
    }


def _write_advice(alarm_name: str, advice: dict) -> None:
    ssm.put_parameter(
        Name=f"{SSM_ADVICE_KEY}/{alarm_name}",
        Value=json.dumps(advice),
        Type="String",
        Overwrite=True,
    )
    logger.info("Scaling advice written to SSM: alarm=%s", alarm_name)
