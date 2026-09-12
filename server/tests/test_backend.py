import pytest
import time
from fastapi.testclient import TestClient
from server.main import app
from server.store import BurnerStore
from server.models import (
    ProviderID,
    TaskRequest,
    TaskType,
    ProviderQuota,
    ProviderStatus,
    PromptOptimizationRequest,
)
from server.adapters.adapter_manager import AdapterManager
from server.adapters.detector import SystemDetector
from server.agent import BurnerAgent

client = TestClient(app)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"


def test_get_status_returns_detected_providers():
    response = client.get("/api/status")
    assert response.status_code == 200
    data = response.json()
    providers = data["providers"]
    assert len(providers) >= 1
    assert "detected_providers" in data
    assert "enabled_providers" in data
    assert "burn_forecasts" in data

    for p in providers:
        assert 0.0 <= p["quota_remaining_percent"] <= 100.0
        assert p["resets_in_seconds"] >= 0
        assert p["status"] in ["healthy", "warning", "critical", "exhausted"]


def test_provider_detection_and_toggle():
    # 1. Get detection info
    det_res = client.get("/api/providers/detected")
    assert det_res.status_code == 200
    det_list = det_res.json()
    assert len(det_list) == 5

    # 2. Toggle off codex
    toggle_res = client.post("/api/providers/toggle", json={"provider_id": "codex", "enabled": False})
    assert toggle_res.status_code == 200
    assert "codex" not in toggle_res.json()["active_enabled_providers"]

    # 3. Verify status only returns enabled providers (codex should be absent)
    status_res = client.get("/api/status")
    active_ids = {p["provider_id"] for p in status_res.json()["providers"]}
    assert "codex" not in active_ids

    # 4. Toggle codex back on
    client.post("/api/providers/toggle", json={"provider_id": "codex", "enabled": True})
    status_res2 = client.get("/api/status")
    active_ids2 = {p["provider_id"] for p in status_res2.json()["providers"]}
    assert "codex" in active_ids2


def test_prompt_optimizer_api():
    req = {
        "prompt": "Refactor the authentication middleware to support JWT refresh tokens",
        "task_type": "refactor",
    }
    response = client.post("/api/optimize-prompt", json=req)
    assert response.status_code == 200
    data = response.json()

    assert data["recommended_provider"] in ["claude", "cursor", "codex", "gemini", "copilot"]
    assert len(data["optimized_prompt"]) > len(req["prompt"])
    assert data["estimated_input_tokens"] > 0
    assert data["estimated_output_tokens"] > 0
    assert len(data["token_budget_recommendation"]) > 0
    assert data["launch_target"] is not None


def test_forecast_api():
    response = client.get("/api/forecast")
    assert response.status_code == 200
    forecasts = response.json()
    assert len(forecasts) >= 1
    for f in forecasts:
        assert "provider_id" in f
        assert "safe_prompts_remaining" in f
        assert f["safe_prompts_remaining"] >= 0


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
    assert burn_rate == 20.0
    assert mins_to_deplete == 120


def test_agent_task_routing():
    agent = BurnerAgent()
    quotas = [
        ProviderQuota(provider_id=ProviderID.CLAUDE, name="Claude", quota_remaining_percent=75.0, resets_in_seconds=14000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.CURSOR, name="Cursor", quota_remaining_percent=85.0, resets_in_seconds=800000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.CODEX, name="Codex", quota_remaining_percent=50.0, resets_in_seconds=7000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.GEMINI, name="Gemini", quota_remaining_percent=90.0, resets_in_seconds=50000, status=ProviderStatus.HEALTHY),
        ProviderQuota(provider_id=ProviderID.COPILOT, name="Copilot", quota_remaining_percent=80.0, resets_in_seconds=800000, status=ProviderStatus.HEALTHY),
    ]

    # Quick edit should route to Cursor or Copilot
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
    sim_res = client.post("/api/simulate", json={"provider_id": "claude", "quota_delta": -25.0})
    assert sim_res.status_code == 200

    status_res = client.get("/api/status")
    data = status_res.json()
    claude = next(p for p in data["providers"] if p["provider_id"] == "claude")
    assert claude["is_simulated"] is True

    reset_res = client.post("/api/simulate", json={"provider_id": "claude", "reset": True})
    assert reset_res.status_code == 200


def test_chat_api():
    chat_req = {
        "messages": [
            {"role": "user", "content": "Which tool should I use to save my Claude quota?"}
        ]
    }
    res = client.post("/api/chat", json=chat_req)
    assert res.status_code == 200
    data = res.json()
    assert "message" in data
    assert data["message"]["role"] == "assistant"
    assert len(data["message"]["content"]) > 0
    assert data["engine"] in ["gemini-3.6-flash", "burner-local-strategist"]


def test_handoff_capsule_api():
    req = {
        "source_provider": "claude",
        "task_summary": "Refactor UserAuthToken to validate JWT expiration and refresh cookies",
        "code_snippet": "class UserAuthToken:\n    def validate(self): pass",
        "unresolved_issues": "Token signature mismatch on macOS keychain lookup"
    }
    res = client.post("/api/handoff-capsule", json=req)
    assert res.status_code == 200
    data = res.json()
    assert data["source_provider"] == "claude"
    assert data["target_provider"] in ["cursor", "codex", "gemini", "copilot"]
    assert len(data["capsule_prompt"]) > 50
    assert data["estimated_token_savings"] > 0
    assert data["target_quota_headroom_pct"] > 0
    assert data["launch_target"] is not None


def test_trim_code_api():
    sample_code = """
import os
import sys
import logging

# Verbose license header
# Copyright (c) 2026 Developer Inc. All rights reserved.

class AuthService:
    '''Primary authentication handler for tokens.'''
    def __init__(self, key: str):
        self.key = key
        # Setup logger
        self.logger = logging.getLogger(__name__)

    def authenticate_user(self, user_id: str, secret: str) -> bool:
        # Check credentials
        if not user_id or not secret:
            return False
        return True

    def helper_unused_method(self, data: dict):
        # 10 lines of unused boilerplate
        x = 1
        y = 2
        return x + y
"""
    req = {
        "raw_code": sample_code,
        "mode": "aggressive",
        "task_focus": "authenticate_user"
    }
    res = client.post("/api/trim-code", json=req)
    assert res.status_code == 200
    data = res.json()
    assert data["original_token_count"] > data["trimmed_token_count"]
    assert data["compression_ratio_pct"] > 0.0
    assert len(data["trimmed_code"]) > 0
    assert data["safe_prompts_gained"] >= 0


def test_sprint_plan_api():
    req = {
        "task_description": "Build Stripe Checkout webhook endpoint with database idempotency and test coverage",
        "target_hours": 3.0
    }
    res = client.post("/api/sprint-plan", json=req)
    assert res.status_code == 200
    data = res.json()
    assert data["task_description"] == req["task_description"]
    assert data["total_estimated_tokens"] > 0
    assert data["tokens_saved_vs_monolith"] > 0
    assert data["claude_prompts_preserved"] > 0
    assert len(data["stages"]) == 3
    assert data["stages"][0]["stage_number"] == 1
    assert data["stages"][0]["assigned_provider"] in ["codex", "gemini"]
    assert data["stages"][1]["stage_number"] == 2
    assert data["stages"][1]["assigned_provider"] in ["claude"]
    assert data["stages"][2]["stage_number"] == 3
    assert data["stages"][2]["assigned_provider"] in ["cursor", "copilot"]



