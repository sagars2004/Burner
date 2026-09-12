import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from ..models import (
    ProviderID,
    ProviderQuota,
    ProviderStatus,
    ProviderDetectionInfo,
    SprintBurnForecast,
)
from ..store import BurnerStore
from .detector import SystemDetector
from .claude_adapter import ClaudeAdapter
from .cursor_adapter import CursorAdapter
from .codex_adapter import CodexAdapter
from .gemini_adapter import GeminiAdapter
from .copilot_adapter import CopilotAdapter


class AdapterManager:
    def __init__(self, store: Optional[BurnerStore] = None):
        self.store = store or BurnerStore()
        self.adapters = {
            ProviderID.CLAUDE: ClaudeAdapter(),
            ProviderID.CURSOR: CursorAdapter(),
            ProviderID.CODEX: CodexAdapter(),
            ProviderID.GEMINI: GeminiAdapter(),
            ProviderID.COPILOT: CopilotAdapter(),
        }

    def get_detected_providers(self) -> List[ProviderID]:
        return SystemDetector.get_detected_provider_ids()

    def get_enabled_providers(self) -> List[ProviderID]:
        settings = self.store.get_all_provider_settings()
        detected = self.get_detected_providers()

        enabled = []
        for pid in ProviderID:
            if pid.value in settings:
                if settings[pid.value]:
                    enabled.append(pid)
            else:
                if pid in detected:
                    enabled.append(pid)

        # Fallback: if user disabled everything, keep at least one provider
        if not enabled and detected:
            return [detected[0]]
        return enabled

    def set_provider_enabled(self, provider_id: ProviderID, enabled: bool):
        self.store.set_provider_enabled(provider_id.value, enabled)

    def get_detection_summary(self) -> List[ProviderDetectionInfo]:
        enabled = self.get_enabled_providers()
        return SystemDetector.get_detection_info_list(enabled)

    def get_all_quotas(self, only_enabled: bool = True) -> List[ProviderQuota]:
        enabled_set = set(self.get_enabled_providers()) if only_enabled else set(self.adapters.keys())
        results = []

        for pid, adapter in self.adapters.items():
            if only_enabled and pid not in enabled_set:
                continue

            quota = adapter.get_quota()

            # Check for simulation overrides
            sim_val = self.store.get_simulation_override(pid.value)
            if sim_val is not None:
                quota.quota_remaining_percent = round(sim_val, 1)
                quota.is_simulated = True

            # Recalculate status based on current percentage
            if quota.quota_remaining_percent <= 0:
                quota.status = ProviderStatus.EXHAUSTED
            elif quota.quota_remaining_percent < 20.0:
                quota.status = ProviderStatus.CRITICAL
            elif quota.quota_remaining_percent < 40.0:
                quota.status = ProviderStatus.WARNING
            else:
                quota.status = ProviderStatus.HEALTHY

            # Fetch burn rate and time-to-exhaustion
            burn_rate, mins_to_deplete = self.store.get_burn_rate(pid.value)
            quota.burn_rate_per_hour = burn_rate
            quota.estimated_minutes_to_exhaustion = mins_to_deplete

            # Record sample for history tracking
            self.store.record_sample(pid.value, quota.quota_remaining_percent, quota.plan_name)

            results.append(quota)

        return results

    def get_quota(self, provider_id: ProviderID) -> ProviderQuota:
        adapter = self.adapters[provider_id]
        quota = adapter.get_quota()
        sim_val = self.store.get_simulation_override(provider_id.value)
        if sim_val is not None:
            quota.quota_remaining_percent = round(sim_val, 1)
            quota.is_simulated = True
        return quota

    def get_sprint_burn_forecasts(self) -> List[SprintBurnForecast]:
        forecasts = []
        enabled_quotas = self.get_all_quotas(only_enabled=True)

        for q in enabled_quotas:
            burn_rate = q.burn_rate_per_hour
            rem_pct = q.quota_remaining_percent

            # Safe prompts remaining: assume ~2.5% - 3.5% per standard coding prompt
            avg_cost_per_prompt = 3.0
            safe_prompts = max(0, int(rem_pct / avg_cost_per_prompt))

            lockout_time_str = None
            mins_until_lockout = None
            warning = None

            if burn_rate > 0.5 and rem_pct > 0:
                mins_until_lockout = int((rem_pct / burn_rate) * 60)
                lockout_dt = datetime.now() + timedelta(minutes=mins_until_lockout)
                lockout_time_str = lockout_dt.strftime("%I:%M %p").lstrip("0")

                if mins_until_lockout < 60:
                    warning = f"{q.name} pace will trigger limit lockout around {lockout_time_str} (~{mins_until_lockout}m left)!"
                elif mins_until_lockout < 180:
                    warning = f"{q.name} active burn: projected depletion at {lockout_time_str}."

            forecasts.append(
                SprintBurnForecast(
                    provider_id=q.provider_id,
                    prompts_last_hour=int(burn_rate / 3.0) if burn_rate > 0 else 0,
                    burn_rate_per_hour=burn_rate,
                    estimated_lockout_time=lockout_time_str,
                    minutes_until_lockout=mins_until_lockout,
                    lockout_warning=warning,
                    safe_prompts_remaining=safe_prompts,
                )
            )

        return forecasts

    def simulate_delta(self, provider_id: ProviderID, delta: float) -> float:
        current_base = self.get_quota(provider_id).quota_remaining_percent
        return self.store.adjust_simulation_override(provider_id.value, delta, current_base)

    def set_simulation_quota(self, provider_id: ProviderID, quota: float):
        self.store.set_simulation_override(provider_id.value, quota)

    def reset_simulations(self):
        self.store.reset_simulations()
