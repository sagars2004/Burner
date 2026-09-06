from typing import Dict, List, Optional
from ..models import ProviderID, ProviderQuota, ProviderStatus
from ..store import BurnerStore
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

    def get_all_quotas(self) -> List[ProviderQuota]:
        results = []
        for pid, adapter in self.adapters.items():
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

    def simulate_delta(self, provider_id: ProviderID, delta: float) -> float:
        current_base = self.get_quota(provider_id).quota_remaining_percent
        return self.store.adjust_simulation_override(provider_id.value, delta, current_base)

    def set_simulation_quota(self, provider_id: ProviderID, quota: float):
        self.store.set_simulation_override(provider_id.value, quota)

    def reset_simulations(self):
        self.store.reset_simulations()
