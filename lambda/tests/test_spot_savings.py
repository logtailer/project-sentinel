import json
import os
from datetime import date, timedelta
from unittest.mock import MagicMock, patch

import pytest

os.environ.setdefault("CLUSTER_NAME", "sentinel-dev")
os.environ.setdefault("SSM_SAVINGS_KEY", "/dev/sentinel/savings")

from spot_savings.handler import handler


def _scheduler_event() -> dict:
    return {"source": "scheduler"}


@patch("spot_savings.handler.ce")
@patch("spot_savings.handler.ssm")
def test_writes_weekly_savings_report(mock_ssm, mock_ce):
    end = date.today()
    start = end - timedelta(days=7)

    mock_ce.get_cost_and_usage.return_value = {
        "ResultsByTime": [
            {
                "Groups": [
                    {
                        "Keys": ["Spot"],
                        "Metrics": {"UnblendedCost": {"Amount": "12.50"}},
                    },
                    {
                        "Keys": ["On Demand"],
                        "Metrics": {"UnblendedCost": {"Amount": "45.00"}},
                    },
                ]
            }
        ]
    }
    mock_ssm.put_parameter = MagicMock()

    result = handler(_scheduler_event(), None)

    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["cluster"] == "sentinel-dev"
    assert body["spot_cost_usd"] == 12.5
    assert body["on_demand_equivalent_usd"] == 45.0
    assert body["spot_savings_pct"] == pytest.approx(72.22, rel=1e-2)

    mock_ssm.put_parameter.assert_called_once()
    call_kwargs = mock_ssm.put_parameter.call_args[1]
    assert call_kwargs["Name"] == "/dev/sentinel/savings/weekly"


@patch("spot_savings.handler.ce")
@patch("spot_savings.handler.ssm")
def test_handles_zero_on_demand_cost(mock_ssm, mock_ce):
    mock_ce.get_cost_and_usage.return_value = {
        "ResultsByTime": [
            {
                "Groups": [
                    {
                        "Keys": ["Spot"],
                        "Metrics": {"UnblendedCost": {"Amount": "8.00"}},
                    }
                ]
            }
        ]
    }
    mock_ssm.put_parameter = MagicMock()

    result = handler(_scheduler_event(), None)
    body = json.loads(result["body"])
    assert body["spot_savings_pct"] == 0.0
