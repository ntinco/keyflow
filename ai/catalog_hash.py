"""Canonical content hashing for reviewed hotkey catalog items."""
from __future__ import annotations

import hashlib
import json


def catalog_items_sha256(items: object) -> str:
    """Return the stable SHA-256 used to bind human review to catalog content."""
    canonical = json.dumps(items, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()
