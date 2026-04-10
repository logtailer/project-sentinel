"""
Validates that the node remediation Lambda correctly handles a NodeNotReady
event that would be triggered after an AWS FIS spot termination experiment.
This test uses the same mock setup as test_node_remediation.py but simulates
the specific event shape that FIS-induced termination produces.
"""
import json
import os

import boto3
import pytest
from moto import mock_aws

os.environ.setdefault("CLUSTER_NAME", "sentinel-dev")
os.environ.setdefault("NODE_GROUP_NAME", "sentinel-dev-general")
os.environ.setdefault("SSM_REMEDIATION_KEY", "/dev/sentinel/remediation/nodes")

from node_remediation.handler import handler


def _fis_termination_event(node_name: str = "ip-10-0-2-77") -> dict:
    return {
        "source": "aws.eks",
        "detail-type": "EKS Managed Node Group Health Issue",
        "detail": {
            "reason": "NodeNotReady",
            "involvedObject": {"name": node_name},
            "annotations": {"chaos-source": "aws-fis"},
        },
    }


@mock_aws
def test_remediation_triggered_after_fis_termination():
    eks = boto3.client("eks", region_name="us-east-1")
    ssm = boto3.client("ssm", region_name="us-east-1")

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

    result = handler(_fis_termination_event("ip-10-0-2-77"), None)

    assert result["statusCode"] == 200
    assert "ip-10-0-2-77" in result["body"]

    param = ssm.get_parameter(Name="/dev/sentinel/remediation/nodes/ip-10-0-2-77")
    value = json.loads(param["Parameter"]["Value"])
    assert value["action"] == "rolling_update"
    assert value["node"] == "ip-10-0-2-77"
