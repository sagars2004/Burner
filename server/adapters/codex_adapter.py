import json
import time
from pathlib import Path
from typing import Tuple
from ..models import ProviderID, ProviderQuota, ProviderStatus


class CodexAdapter:
    PROVIDER_ID = ProviderID.CODEX
    NAME = "Codex"
    PLAN_NAME = "Free Tier (GPT-4o mini)"
    ICON = "sparkles"
    WINDOW_SECONDS = 3 * 3600  # 3-hour rolling window

    def __init__(self):
        self.config_paths = [
            Path.home() / ".codex/config.json",
            Path.home() / ".config/codex/credentials.json",
            Path.home() / ".openai/config.json",
        ]

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
        for path in self.config_paths:
            if path.exists():
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    if "usage" in data:
                        used = data["usage"].get("tokens_used", 0)
                        total = data["usage"].get("token_limit", 100000)
                        rem = max(0.0, (1.0 - (used / total)) * 100.0)
                        return rem, 7200, False
                except Exception:
                    pass

        # Realistic default: Codex at 52% remaining, resets in 1h 45m
        cycle_sec = int(time.time()) % self.WINDOW_SECONDS
        remaining_sec = self.WINDOW_SECONDS - cycle_sec
        return 52.0, remaining_sec, True
