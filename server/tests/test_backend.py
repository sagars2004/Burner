import pytest
import time
from fastapi.testclient import TestClient
from server.main import app
from server.store import BurnerStore
from server.models import ProviderID, TaskRequest, TaskType, ProviderQuota, ProviderStatus
from server.adapters.adapter_manager import AdapterManager
from server.agent import BurnerAgent

client = TestClient(app)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"


def test_get_status_returns_five_providers():
    response = client.get("/api/status")
    assert response.status_code == 200
    data = response.json()
    providers = data["providers"]
    assert len(providers) == 5

    provider_ids = {p["provider_id"] for p in providers}
    assert provider_ids == {"claude", "cursor", "codex", "gemini", "copilot"}

    for p in providers:
        assert 0.0 <= p["quota_remaining_percent"] <= 100.0
        assert p["resets_in_seconds"] >= 0
        assert p["status"] in ["healthy", "warning", "critical", "exhausted"]


def test_store_burn_rate_calculation(tmp_path):
    db_file = str(tmp_path / "test_burner.db")
    store = BurnerStore(db_path=db_file)

    now = time.time()
    # 2 hours ago: 80% quota
    store.record_sample("claude", 80.0, timestamp=now - 7200)
    # 1 hour ago: 60% quota
    store.record_sample("claude", 60.0, timestamp=now - 3600)
    # now: 40% quota (consumed 40% in 2 hours -> 20%/hr)
    store.record_sample("claude", 40.0, timestamp=now)

    burn_rate, mins_to_deplete = store.get_burn_rate("claude", window_minutes=180)
    assert burn_rate == 20.0  # 40% drop over 2 hours = 20%/hr
    assert mins_to_deplete == 120  # 40% remaining / 20%/hr = 2 hours = 120 min


def test_agent_task_routing():
    agent = BurnerAgent()
    quotas = [
        ProviderQuota(provider_id=ProviderID.CLAUDE, name="Claude", quota_remaining_percent=75.0, resets_in_seconds=14000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.CURSOR, name="Cursor", quota_remaining_percent=85.0, resets_in_seconds=800000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.CODEX, name="Codex", quota_remaining_percent=50.0, resets_in_seconds=7000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.GEMINI, name="Gemini", quota_remaining_percent=90.0, resets_in_seconds=50000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.COPILOT, name="Copilot", quota_remaining_percent=80.0, resets_in_seconds=800000, status=ProviderStatus.HEALTHY),
    ]

    # Quick edit should route to Cursor or Copilot to save heavy quota
    quick_req = TaskRequest(task_type=TaskType.QUICK_EDIT)
    rec_quick = agent.recommend(quick_req, quotas)
    assert rec_quick.recommended_provider in (ProviderID.CURSOR, ProviderID.COPILOT)

    # Refactor should favor Claude 3.5 Sonnet
    refactor_req = TaskRequest(task_type=TaskType.REFACTOR)
    rec_refactor = agent.recommend(refactor_req, quotas)
    assert rec_refactor.recommended_provider == ProviderID.CLAUDE


def test_agent_limit_avoidance_when_quota_critical():
    agent = BurnerAgent()
    # Claude is down to 10%
    quotas = [
        ProviderQuota(provider_id=ProviderID.CLAUDE, name="Claude", quota_remaining_percent=10.0, resets_in_seconds=14000, status=ProviderStatus.CRITICAL),
        ProviderQuota(provider_id=ProviderID.CURSOR, name="Cursor", quota_remaining_percent=85.0, resets_in_seconds=800000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.CODEX, name="Codex", quota_remaining_percent=50.0, resets_in_seconds=7000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.GEMINI, name="Gemini", quota_remaining_percent=90.0, resets_in_seconds=50000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.COPILOT, name="Copilot", quota_remaining_percent=80.0, resets_in_seconds=800000, status=ProviderStatus.HEALTHY),
    ]

    refactor_req = TaskRequest(task_type=TaskType.REFACTOR)
    rec = agent.recommend(refactor_req, quotas)

    # Should reroute to Gemini instead of exhausting Claude!
    assert rec.recommended_provider == ProviderID.GEMINI
    assert rec.burn_rate_warning is not None
    assert "critical" in rec.burn_rate_warning.lower()


def test_simulate_api():
    # Simulate dropping Claude by 25%
    sim_res = client.post("/api/simulate", json={"provider_id": "claude", "quota_delta": -25.0})
    assert sim_res.status_code == 200

    # Verify status reflects simulation
    status_res = client.get("/api/status")
    data = status_res.json()
    claude = next(p for p in data["providers"] if p["provider_id"] == "claude")
    assert claude["is_simulated"] is True

    # Reset simulation
    reset_res = client.post("/api/simulate", json={"provider_id": "claude", "reset": True})
    assert reset_res.status_code == 200
