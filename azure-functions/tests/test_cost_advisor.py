import json
import os
import unittest
from unittest.mock import MagicMock, patch


class TestCostAdvisor(unittest.TestCase):
    def setUp(self):
        os.environ["AZURE_SUBSCRIPTION_ID"] = "00000000-0000-0000-0000-000000000000"
        os.environ["KEY_VAULT_URI"] = "https://kv-sentinel-dev.vault.azure.net/"
        os.environ["CLUSTER_NAME"] = "sentinel-aks-dev"

    @patch("cost_advisor.SecretClient")
    @patch("cost_advisor.CostManagementClient")
    @patch("cost_advisor.DefaultAzureCredential")
    def test_writes_cost_report(self, mock_cred, mock_cost_cls, mock_kv_cls):
        mock_kv = MagicMock()
        mock_kv_cls.return_value = mock_kv

        mock_cost = MagicMock()
        mock_cost_cls.return_value = mock_cost

        mock_result = MagicMock()
        mock_result.rows = [
            [12.50, "Spot"],
            [87.30, "OnDemand"],
        ]
        mock_cost.query.usage.return_value = mock_result

        timer = MagicMock()
        timer.past_due = False

        from cost_advisor import main
        main(timer)

        mock_kv.set_secret.assert_called_once()
        secret_value = json.loads(mock_kv.set_secret.call_args[0][1])

        self.assertEqual(secret_value["spot_cost_usd"], 12.5)
        self.assertEqual(secret_value["payg_cost_usd"], 87.3)
        self.assertGreater(secret_value["spot_savings_pct"], 0)
        self.assertEqual(secret_value["period_days"], 7)

    @patch("cost_advisor.SecretClient")
    @patch("cost_advisor.CostManagementClient")
    @patch("cost_advisor.DefaultAzureCredential")
    def test_zero_payg_cost_no_division_error(self, mock_cred, mock_cost_cls, mock_kv_cls):
        mock_kv = MagicMock()
        mock_kv_cls.return_value = mock_kv

        mock_cost = MagicMock()
        mock_cost_cls.return_value = mock_cost

        mock_result = MagicMock()
        mock_result.rows = []
        mock_cost.query.usage.return_value = mock_result

        timer = MagicMock()
        from cost_advisor import main
        main(timer)

        secret_value = json.loads(mock_kv.set_secret.call_args[0][1])
        self.assertEqual(secret_value["spot_savings_pct"], 0)


if __name__ == "__main__":
    unittest.main()
