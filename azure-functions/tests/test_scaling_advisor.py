import json
import os
import unittest
from unittest.mock import MagicMock, patch


class TestScalingAdvisor(unittest.TestCase):
    def setUp(self):
        os.environ["KEY_VAULT_URI"] = "https://kv-sentinel-dev.vault.azure.net/"
        os.environ["CLUSTER_NAME"] = "sentinel-aks-dev"

    @patch("scaling_advisor.SecretClient")
    @patch("scaling_advisor.DefaultAzureCredential")
    def test_writes_scale_out_advice(self, mock_cred, mock_kv_cls):
        mock_kv = MagicMock()
        mock_kv_cls.return_value = mock_kv

        event = MagicMock()
        event.get_json.return_value = {
            "data": {
                "essentials": {
                    "alertRule": "high-cpu-alert"
                }
            }
        }

        from scaling_advisor import main
        main(event)

        mock_kv.set_secret.assert_called_once()
        call_args = mock_kv.set_secret.call_args
        secret_name = call_args[0][0]
        secret_value = json.loads(call_args[0][1])

        self.assertIn("sentinel-aks-dev", secret_name)
        self.assertEqual(secret_value["recommendation"], "scale_out")
        self.assertEqual(secret_value["trigger"], "high-cpu-alert")

    @patch("scaling_advisor.SecretClient")
    @patch("scaling_advisor.DefaultAzureCredential")
    def test_unknown_alert_still_writes(self, mock_cred, mock_kv_cls):
        mock_kv = MagicMock()
        mock_kv_cls.return_value = mock_kv

        event = MagicMock()
        event.get_json.return_value = {}

        from scaling_advisor import main
        main(event)

        mock_kv.set_secret.assert_called_once()
        secret_value = json.loads(mock_kv.set_secret.call_args[0][1])
        self.assertEqual(secret_value["trigger"], "unknown")


if __name__ == "__main__":
    unittest.main()
