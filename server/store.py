import sqlite3
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class BurnerStore:
    def __init__(self, db_path: Optional[str] = None):
        if db_path is None:
            db_dir = Path(__file__).parent / "data"
            db_dir.mkdir(parents=True, exist_ok=True)
            self.db_path = str(db_dir / "burner_history.db")
        else:
            self.db_path = db_path

        self._init_db()
        self._simulation_overrides: Dict[str, float] = {}

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self):
        with self._get_connection() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS usage_samples (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp REAL NOT NULL,
                    provider_id TEXT NOT NULL,
                    quota_remaining REAL NOT NULL,
                    plan_name TEXT NOT NULL
                )
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_provider_time 
                ON usage_samples (provider_id, timestamp)
            """)
            conn.commit()

    def record_sample(self, provider_id: str, quota_remaining: float, plan_name: str = "Free Tier", timestamp: Optional[float] = None):
        ts = timestamp if timestamp is not None else time.time()
        with self._get_connection() as conn:
            conn.execute("""
                INSERT INTO usage_samples (timestamp, provider_id, quota_remaining, plan_name)
                VALUES (?, ?, ?, ?)
            """, (ts, provider_id, quota_remaining, plan_name))
            conn.commit()

    def get_burn_rate(self, provider_id: str, window_minutes: int = 60) -> Tuple[float, Optional[int]]:
        """
        Calculates burn rate (% consumed per hour) over window_minutes and estimated minutes to exhaustion.
        Returns (burn_rate_per_hour, estimated_minutes_to_exhaustion).
        """
        cutoff = time.time() - (window_minutes * 60)
        with self._get_connection() as conn:
            rows = conn.execute("""
                SELECT timestamp, quota_remaining FROM usage_samples
                WHERE provider_id = ? AND timestamp >= ?
                ORDER BY timestamp ASC
            """, (provider_id, cutoff)).fetchall()

        if len(rows) < 2:
            return 0.0, None

        first_ts, first_quota = rows[0]["timestamp"], rows[0]["quota_remaining"]
        last_ts, last_quota = rows[-1]["timestamp"], rows[-1]["quota_remaining"]

        elapsed_hours = (last_ts - first_ts) / 3600.0
        if elapsed_hours <= 0.001:
            return 0.0, None

        quota_delta = first_quota - last_quota  # positive if consuming
        if quota_delta <= 0:
            return 0.0, None

        burn_rate_per_hour = quota_delta / elapsed_hours

        if burn_rate_per_hour > 0 and last_quota > 0:
            hours_to_deplete = last_quota / burn_rate_per_hour
            mins_to_deplete = int(hours_to_deplete * 60)
            return round(burn_rate_per_hour, 1), mins_to_deplete

        return round(burn_rate_per_hour, 1), None

    def set_simulation_override(self, provider_id: str, quota: float):
        clamped = max(0.0, min(100.0, quota))
        self._simulation_overrides[provider_id] = clamped
        self.record_sample(provider_id, clamped, plan_name="Simulated")

    def adjust_simulation_override(self, provider_id: str, delta: float, current_base_quota: float):
        current = self._simulation_overrides.get(provider_id, current_base_quota)
        new_quota = max(0.0, min(100.0, current + delta))
        self._simulation_overrides[provider_id] = new_quota
        self.record_sample(provider_id, new_quota, plan_name="Simulated")
        return new_quota

    def get_simulation_override(self, provider_id: str) -> Optional[float]:
        return self._simulation_overrides.get(provider_id)

    def reset_simulations(self):
        self._simulation_overrides.clear()
