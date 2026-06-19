import json
import os
import unittest
from unittest.mock import MagicMock, patch, call


class TestNodeRemediation(unittest.TestCase):
    def setUp(self):
        os.environ["AZURE_SUBSCRIPTION_ID"] = "00000000-0000-0000-0000-000000000000"
        os.environ["CLUSTER_RESOURCE_GROUP"] = "rg-sentinel-dev"
        os.environ["CLUSTER_NAME"] = "sentinel-aks-dev"
        os.environ["NODE_POOL_NAME"] = "user"
        os.environ["KEY_VAULT_URI"] = "https://kv-sentinel-dev.vault.azure.net/"

    @patch("node_remediation.SecretClient")
    @patch("node_remediation.ContainerServiceClient")
    @patch("node_remediation.DefaultAzureCredential")
    def test_triggers_node_image_upgrade(self, mock_cred, mock_aks_cls, mock_kv_cls):
        mock_aks = MagicMock()
        mock_aks_cls.return_value = mock_aks
        mock_kv = MagicMock()
        mock_kv_cls.return_value = mock_kv

        mock_poller = MagicMock()
        mock_aks.agent_pools.begin_upgrade_node_image_version.return_value = mock_poller

        event = MagicMock()
        event.get_json.return_value = {
            "subject": "nodes/aks-user-12345678-vmss000001",
            "eventTime": "2026-05-29T10:00:00Z",
        }

        from node_remediation import main
        main(event)

        mock_aks.agent_pools.begin_upgrade_node_image_version.assert_called_once_with(
            "rg-sentinel-dev", "sentinel-aks-dev", "user"
        )
        mock_poller.result.assert_called_once()

    @patch("node_remediation.SecretClient")
    @patch("node_remediation.ContainerServiceClient")
    @patch("node_remediation.DefaultAzureCredential")
    def test_writes_remediation_record_to_key_vault(self, mock_cred, mock_aks_cls, mock_kv_cls):
        mock_aks = MagicMock()
        mock_aks_cls.return_value = mock_aks
        mock_kv = MagicMock()
        mock_kv_cls.return_value = mock_kv

        event = MagicMock()
        event.get_json.return_value = {
            "subject": "nodes/aks-user-99999999-vmss000003",
            "eventTime": "2026-05-29T10:05:00Z",
        }

        from node_remediation import main
        main(event)

        mock_kv.set_secret.assert_called_once()
        secret_name, secret_value = mock_kv.set_secret.call_args[0]
        record = json.loads(secret_value)

        self.assertIn("remediation", secret_name)
        self.assertEqual(record["action"], "node-image-upgrade")
        self.assertEqual(record["trigger"], "NodeNotReady")


if __name__ == "__main__":
    unittest.main()
