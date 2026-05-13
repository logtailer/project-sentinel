import logging
import os
import json

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.mgmt.costmanagement import CostManagementClient
from azure.mgmt.costmanagement.models import QueryDefinition, QueryTimePeriod, QueryDataset, QueryAggregation, QueryGrouping
from datetime import datetime, timezone, timedelta

logger = logging.getLogger(__name__)

credential = DefaultAzureCredential()


def main(timer: func.TimerRequest) -> None:
    logger.info("Cost advisor triggered")

    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    key_vault_uri = os.environ["KEY_VAULT_URI"]
    cluster_name = os.environ["CLUSTER_NAME"]

    cost_client = CostManagementClient(credential)

    end = datetime.now(timezone.utc)
    start = end - timedelta(days=7)

    scope = f"/subscriptions/{subscription_id}"

    query = QueryDefinition(
        type="ActualCost",
        timeframe="Custom",
        time_period=QueryTimePeriod(from_property=start, to=end),
        dataset=QueryDataset(
            granularity="None",
            aggregation={"totalCost": QueryAggregation(name="Cost", function="Sum")},
            grouping=[QueryGrouping(type="Dimension", name="PricingModel")],
            filter={
                "tags": {
                    "name": "kubernetes.io/cluster/" + cluster_name,
                    "operator": "In",
                    "values": ["owned"]
                }
            },
        ),
    )

    result = cost_client.query.usage(scope=scope, parameters=query)

    spot_cost = 0.0
    payg_cost = 0.0
    for row in result.rows:
        cost_value = float(row[0])
        pricing_model = row[1]
        if pricing_model == "Spot":
            spot_cost = cost_value
        elif pricing_model == "OnDemand":
            payg_cost = cost_value

    total = spot_cost + payg_cost
    savings_pct = ((payg_cost - spot_cost) / payg_cost * 100) if payg_cost > 0 else 0

    report = {
        "cluster": cluster_name,
        "period_days": 7,
        "spot_cost_usd": round(spot_cost, 4),
        "payg_cost_usd": round(payg_cost, 4),
        "total_cost_usd": round(total, 4),
        "spot_savings_pct": round(savings_pct, 2),
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }

    kv_client = SecretClient(vault_url=key_vault_uri, credential=credential)
    kv_client.set_secret(f"cost-report-{cluster_name}-weekly", json.dumps(report))

    logger.info("Cost report written to Key Vault: %s", report)
