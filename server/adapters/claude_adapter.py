import json
import time
from pathlib import Path
from typing import Optional, Tuple
from ..models import ProviderID, ProviderQuota, ProviderStatus


class ClaudeAdapter:
    PROVIDER_ID = ProviderID.CLAUDE
    NAME = "Claude"
    PLAN_NAME = "Free Tier (Sonnet 3.5)"
    ICON = "brain.head.profile"
    WINDOW_SECONDS = 5 * 3600  # Claude rolling 5-hour window
    MAX_REQUESTS_PER_WINDOW = 35

    def __init__(self):
        self.history_path = Path.home() / "Library/Application Support/Claude/plan-usage-history.json"

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
        if self.history_path.exists():
            try:
                with open(self.history_path, "r", encoding="utf-8") as f:
                    data = json.load(f)

                samples = data if isinstance(data, list) else data.get("samples", [])

                if isinstance(samples, list) and len(samples) > 0:
                    now_ms = time.time() * 1000
                    window_start_ms = now_ms - (self.WINDOW_SECONDS * 1000)

                    recent_entries = [
                        entry for entry in samples
                        if isinstance(entry, dict) and entry.get("t", 0) >= window_start_ms
                    ]
                    count = len(recent_entries)

                    # Calculate quota remaining
                    used_ratio = min(1.0, count / self.MAX_REQUESTS_PER_WINDOW)
                    remaining_pct = max(5.0, (1.0 - used_ratio) * 100.0)

                    # Reset countdown: time until oldest entry in current window expires
                    if recent_entries:
                        oldest_ts = min(entry.get("t", now_ms) for entry in recent_entries)
                        oldest_age_sec = (now_ms - oldest_ts) / 1000.0
                        resets_in = max(300, self.WINDOW_SECONDS - oldest_age_sec)
                    else:
                        resets_in = self.WINDOW_SECONDS

                    return remaining_pct, int(resets_in), False
            except Exception:
                pass

        # Fallback realistic state for demo if no active local session
        # Cycle reset around 3.5 hours
        cycle_sec = int(time.time()) % self.WINDOW_SECONDS
        remaining_sec = self.WINDOW_SECONDS - cycle_sec
        return 68.0, remaining_sec, True
