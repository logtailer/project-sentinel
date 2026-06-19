import logging
import os
import json

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.mgmt.containerservice import ContainerServiceClient
from azure.keyvault.secrets import SecretClient

logger = logging.getLogger(__name__)

credential = DefaultAzureCredential()


def main(event: func.EventGridEvent) -> None:
    data = event.get_json()
    logger.info("Node remediation triggered: %s", json.dumps(data))

    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    resource_group = os.environ["CLUSTER_RESOURCE_GROUP"]
    cluster_name = os.environ["CLUSTER_NAME"]
    node_pool_name = os.environ.get("NODE_POOL_NAME", "user")
    key_vault_uri = os.environ["KEY_VAULT_URI"]

    aks_client = ContainerServiceClient(credential, subscription_id)
    kv_client = SecretClient(vault_url=key_vault_uri, credential=credential)

    node_name = data.get("subject", "unknown")

    aks_client.agent_pools.begin_upgrade_node_image_version(
        resource_group, cluster_name, node_pool_name
    ).result()

    record = json.dumps({
        "node": node_name,
        "action": "node-image-upgrade",
        "trigger": "NodeNotReady",
        "timestamp": data.get("eventTime"),
    })

    kv_client.set_secret(f"remediation-{node_name.replace('/', '-')}", record)
    logger.info("Remediation record written to Key Vault for node %s", node_name)
