import json
import sqlite3
import time
from pathlib import Path
from typing import Tuple
from ..models import ProviderID, ProviderQuota, ProviderStatus


class CursorAdapter:
    PROVIDER_ID = ProviderID.CURSOR
    NAME = "Cursor"
    PLAN_NAME = "Fast Requests (Free)"
    ICON = "cursorarrow.rays"
    MONTHLY_SECONDS = 30 * 24 * 3600

    def __init__(self):
        self.db_path = Path.home() / "Library/Application Support/Cursor/User/globalStorage/state.vscdb"

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
        if self.db_path.exists():
            try:
                conn = sqlite3.connect(f"file:{self.db_path}?mode=ro", uri=True)
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT value FROM ItemTable WHERE key IN ('cursorAuth/usage', 'cursorAuth/cachedMembershipType', 'anysphere.cursor-usage') LIMIT 5"
                )
                rows = cursor.fetchall()
                conn.close()

                for (val,) in rows:
                    if isinstance(val, (bytes, bytearray)):
                        val = val.decode("utf-8", errors="ignore")
                    if isinstance(val, str) and ("numRequests" in val or "usage" in val):
                        parsed = json.loads(val)
                        # Extract fast request count if present
                        num_requests = parsed.get("numRequests", 0)
                        max_requests = parsed.get("maxRequests", 50)
                        if max_requests > 0:
                            rem = max(0.0, (1.0 - (num_requests / max_requests)) * 100.0)
                            return rem, 14 * 24 * 3600, False
            except Exception:
                pass

        # Realistic default: Cursor at 84% remaining, resets in ~12 days
        cycle_sec = int(time.time()) % (14 * 24 * 3600)
        remaining_sec = (14 * 24 * 3600) - cycle_sec
        return 84.0, remaining_sec, True
