import json
import os
from datetime import datetime, timedelta, timezone

import boto3

CLUSTER_NAME = os.environ["CLUSTER_NAME"]
SSM_SAVINGS_KEY = os.environ["SSM_SAVINGS_KEY"]
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")

ce = boto3.client("ce", region_name="us-east-1")
ssm = boto3.client("ssm", region_name=REGION)


def handler(event: dict, context) -> dict:
    end = datetime.now(tz=timezone.utc).date()
    start = end - timedelta(days=7)

    spot_cost, on_demand_cost = _get_costs(str(start), str(end))
    total = spot_cost + on_demand_cost
    savings_pct = ((on_demand_cost - spot_cost) / on_demand_cost * 100) if on_demand_cost > 0 else 0

    report = {
        "cluster": CLUSTER_NAME,
        "period": {"start": str(start), "end": str(end)},
        "spot_cost_usd": round(spot_cost, 4),
        "on_demand_equivalent_usd": round(on_demand_cost, 4),
        "total_usd": round(total, 4),
        "spot_savings_pct": round(savings_pct, 2),
        "generated_at": datetime.now(tz=timezone.utc).isoformat(),
    }

    ssm.put_parameter(
        Name=f"{SSM_SAVINGS_KEY}/weekly",
        Value=json.dumps(report),
        Type="String",
        Overwrite=True,
    )

    return {"statusCode": 200, "body": json.dumps(report)}


def _get_costs(start: str, end: str) -> tuple[float, float]:
    response = ce.get_cost_and_usage(
        TimePeriod={"Start": start, "End": end},
        Granularity="MONTHLY",
        Filter={
            "And": [
                {
                    "Tags": {
                        "Key": "kubernetes.io/cluster/" + CLUSTER_NAME,
                        "Values": ["owned"],
                    }
                },
                {"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Elastic Compute Cloud - Compute"]}},
            ]
        },
        GroupBy=[{"Type": "DIMENSION", "Key": "PURCHASE_TYPE"}],
        Metrics=["UnblendedCost"],
    )

    spot_cost = 0.0
    on_demand_cost = 0.0
    for result in response.get("ResultsByTime", []):
        for group in result.get("Groups", []):
            purchase_type = group["Keys"][0]
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            if purchase_type == "Spot":
                spot_cost += amount
            elif purchase_type == "On Demand":
                on_demand_cost += amount

    return spot_cost, on_demand_cost
