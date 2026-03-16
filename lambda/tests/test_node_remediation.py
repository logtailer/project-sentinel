import json
import os

import boto3
import pytest
from moto import mock_aws

os.environ.setdefault("CLUSTER_NAME", "sentinel-dev")
os.environ.setdefault("NODE_GROUP_NAME", "sentinel-dev-general")
os.environ.setdefault("SSM_REMEDIATION_KEY", "/dev/sentinel/remediation/nodes")

from node_remediation.handler import handler


def _node_not_ready_event(node_name: str = "ip-10-0-1-100") -> dict:
    return {
        "source": "aws.eks",
        "detail-type": "EKS Managed Node Group Health Issue",
        "detail": {
            "reason": "NodeNotReady",
            "involvedObject": {"name": node_name},
        },
    }


@mock_aws
def test_ignores_non_actionable_reason():
    event = _node_not_ready_event()
    event["detail"]["reason"] = "NodeReady"
    result = handler(event, None)
    assert result["statusCode"] == 200
    assert result["body"] == "skipped"


@mock_aws
def test_records_remediation_event_to_ssm():
    import boto3

    ssm = boto3.client("ssm", region_name="us-east-1")
    eks = boto3.client("eks", region_name="us-east-1")

    # moto requires the cluster and node group to exist before describe calls
    eks.create_cluster(
        name="sentinel-dev",
        version="1.30",
        roleArn="arn:aws:iam::123456789012:role/eks-role",
        resourcesVpcConfig={"subnetIds": ["subnet-abc"]},
    )
    eks.create_nodegroup(
        clusterName="sentinel-dev",
        nodegroupName="sentinel-dev-general",
        nodeRole="arn:aws:iam::123456789012:role/node-role",
        subnets=["subnet-abc"],
        scalingConfig={"minSize": 1, "maxSize": 10, "desiredSize": 2},
    )

    result = handler(_node_not_ready_event("ip-10-0-1-55"), None)
    assert result["statusCode"] == 200
    assert "ip-10-0-1-55" in result["body"]

    param = ssm.get_parameter(Name="/dev/sentinel/remediation/nodes/ip-10-0-1-55")
    value = json.loads(param["Parameter"]["Value"])
    assert value["action"] == "rolling_update"
    assert value["node"] == "ip-10-0-1-55"
