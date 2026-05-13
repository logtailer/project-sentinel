import logging
import os
import json

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.monitor.query import MetricsQueryClient
from datetime import datetime, timezone, timedelta

logger = logging.getLogger(__name__)

credential = DefaultAzureCredential()


def main(event: func.EventGridEvent) -> None:
    data = event.get_json()
    logger.info("Scaling advisor triggered: %s", json.dumps(data))

    key_vault_uri = os.environ["KEY_VAULT_URI"]
    cluster_name = os.environ["CLUSTER_NAME"]

    alert_name = data.get("data", {}).get("essentials", {}).get("alertRule", "unknown")

    advice = {
        "cluster": cluster_name,
        "recommendation": "scale_out",
        "trigger": alert_name,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    kv_client = SecretClient(vault_url=key_vault_uri, credential=credential)
    kv_client.set_secret(f"scaling-advice-{cluster_name}", json.dumps(advice))

    logger.info("Scaling advice written to Key Vault: %s", advice)
