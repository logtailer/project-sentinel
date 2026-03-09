import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

eks = boto3.client("eks")
ssm = boto3.client("ssm")

CLUSTER_NAME = os.environ["CLUSTER_NAME"]
NODE_GROUP_NAME = os.environ["NODE_GROUP_NAME"]
SSM_REMEDIATION_KEY = os.environ["SSM_REMEDIATION_KEY"]


def handler(event: dict, context) -> dict:
    logger.info("Received event: %s", json.dumps(event))

    detail = event.get("detail", {})
    node_name = detail.get("involvedObject", {}).get("name", "unknown")
    reason = detail.get("reason", "")

    if reason != "NodeNotReady":
        logger.info("Ignoring event reason=%s — not actionable", reason)
        return {"statusCode": 200, "body": "skipped"}

    logger.info("NodeNotReady detected: node=%s", node_name)

    try:
        _record_remediation_event(node_name)
        _trigger_node_group_update()
    except ClientError as exc:
        logger.error("Remediation failed: %s", exc)
        raise

    return {"statusCode": 200, "body": f"remediation triggered for node {node_name}"}


def _trigger_node_group_update() -> None:
    """Force a rolling update on the node group to replace the unhealthy node."""
    response = eks.describe_nodegroup(
        clusterName=CLUSTER_NAME,
        nodegroupName=NODE_GROUP_NAME,
    )
    current_config = response["nodegroup"]["scalingConfig"]

    eks.update_nodegroup_config(
        clusterName=CLUSTER_NAME,
        nodegroupName=NODE_GROUP_NAME,
        scalingConfig=current_config,
    )
    logger.info("Rolling update triggered on nodegroup=%s", NODE_GROUP_NAME)


def _record_remediation_event(node_name: str) -> None:
    """Write to SSM so other systems can see remediation history without CloudWatch."""
    ssm.put_parameter(
        Name=f"{SSM_REMEDIATION_KEY}/{node_name}",
        Value=json.dumps({"action": "rolling_update", "node": node_name}),
        Type="String",
        Overwrite=True,
    )
