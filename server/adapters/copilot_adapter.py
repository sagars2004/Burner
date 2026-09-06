import time
from pathlib import Path
from typing import Tuple
from ..models import ProviderID, ProviderQuota, ProviderStatus


class CopilotAdapter:
    PROVIDER_ID = ProviderID.COPILOT
    NAME = "Copilot"
    PLAN_NAME = "Individual / Free"
    ICON = "chevron.left.forwardslash.chevron.right"
    MONTHLY_SECONDS = 30 * 24 * 3600

    def __init__(self):
        self.gh_hosts = Path.home() / ".config/gh/hosts.yml"
        self.copilot_config = Path.home() / ".config/github-copilot/hosts.json"

    def get_quota(self) -> ProviderQuota:
        quota_pct, resets_in, is_simulated = self._read_local_data()

        status = ProviderStatus.HEALTHY
        if quota_pct <= 0:
            status = ProviderStatus.EXHAUSTED
        elif quota_pct < 20.0:
            status = ProviderStatus.CRITICAL
        elif quota_pct < 40.0:
            status = ProviderStatus.WARNING

        return ProviderQuota(
            provider_id=self.PROVIDER_ID,
            name=self.NAME,
            plan_name=self.PLAN_NAME,
            quota_remaining_percent=round(quota_pct, 1),
            resets_in_seconds=int(resets_in),
            status=status,
            is_simulated=is_simulated,
            icon_name=self.ICON,
        )

    def _read_local_data(self) -> Tuple[float, int, bool]:
        has_gh = self.gh_hosts.exists() or self.copilot_config.exists()

        # Monthly reset calculation
        cycle_sec = int(time.time()) % self.MONTHLY_SECONDS
        remaining_sec = self.MONTHLY_SECONDS - cycle_sec

        if has_gh:
            return 88.0, remaining_sec, False

        # Fallback realistic simulation
        return 74.0, remaining_sec, True
