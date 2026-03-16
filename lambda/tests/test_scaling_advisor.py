import json
import os

import pytest
from moto import mock_aws

os.environ.setdefault("CLUSTER_NAME", "sentinel-dev")
os.environ.setdefault("SSM_ADVICE_KEY", "/dev/sentinel/advice/scaling")

from scaling_advisor.handler import handler


def _alarm_event(state: str = "ALARM", alarm_name: str = "high-cpu") -> dict:
    return {
        "source": "aws.cloudwatch",
        "detail-type": "CloudWatch Alarm State Change",
        "detail": {
            "alarmName": alarm_name,
            "state": {"value": state, "reason": "Threshold crossed"},
        },
    }


@mock_aws
def test_ignores_ok_state():
    result = handler(_alarm_event(state="OK"), None)
    assert result["statusCode"] == 200
    assert result["body"] == "skipped"


@mock_aws
def test_writes_advice_on_alarm():
    result = handler(_alarm_event(alarm_name="node-cpu-high"), None)
    assert result["statusCode"] == 200

    import boto3

    ssm = boto3.client("ssm", region_name="us-east-1")
    param = ssm.get_parameter(Name="/dev/sentinel/advice/scaling/node-cpu-high")
    value = json.loads(param["Parameter"]["Value"])
    assert value["recommendation"] == "scale_out"
    assert value["cluster"] == "sentinel-dev"
    assert value["alarm"] == "node-cpu-high"
