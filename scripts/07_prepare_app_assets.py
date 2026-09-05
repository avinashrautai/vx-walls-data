#!/usr/bin/env python3
"""VX Walls — final app asset preparation step.

Copies the current optimized WebP set into wallpapers/app and rewrites
wallpapers.json with stable raw GitHub URLs. This step is deterministic:
the output directory is cleared before publishing the current catalog.

This script does not grant or infer copyright permission. Upstream license
and technical gates remain authoritative.
"""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any

OPTIMIZED_DIR = Path(os.getenv("VX_OPTIMIZED_DIR", "wallpapers/optimized"))
OUTPUT_DIR = Path(os.getenv("VX_OUTPUT_DIR", "wallpapers/app"))
CATALOG = Path(os.getenv("VX_CATALOG", "wallpapers.json"))
RAW_BASE = os.getenv(
    "VX_RAW_BASE_URL",
    "https://raw.githubusercontent.com/avinashrautai/vx-walls-data/main",
).rstrip("/")


def main() -> int:
    if not OPTIMIZED_DIR.is_dir():
        print(f"ERROR: optimized directory not found: {OPTIMIZED_DIR}")
        return 2
    if not CATALOG.is_file():
        print(f"ERROR: catalog not found: {CATALOG}")
        return 2

    try:
        payload: dict[str, Any] = json.loads(CATALOG.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: invalid catalog: {exc}")
        return 2

    walls = payload.get("wallpapers")
    if not isinstance(walls, list):
        print("ERROR: catalog wallpapers must be a list")
        return 2

    # Never leave an old image published when the current catalog no longer
    # contains it.
    if OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    prepared: list[dict[str, Any]] = []
    missing = 0

    for wall in walls:
        if not isinstance(wall, dict):
            continue

        filename = Path(str(wall.get("url") or "")).name
        if not filename or Path(filename).suffix.lower() != ".webp":
            continue

        source = OPTIMIZED_DIR / filename
        if not source.is_file():
            missing += 1
            continue

        shutil.copy2(source, OUTPUT_DIR / filename)
        item = dict(wall)
        item["url"] = f"{RAW_BASE}/wallpapers/app/{filename}"
        item["download_url"] = item["url"]
        item["local_path"] = f"wallpapers/app/{filename}"
        prepared.append(item)

    output = {
        "schema_version": 2,
        "generated_by": "VX Walls App Asset Preparation 1.1",
        "count": len(prepared),
        "wallpapers": prepared,
    }
    CATALOG.write_text(
        json.dumps(output, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print("VX Walls app assets prepared")
    print(f"Published: {len(prepared)}")
    print(f"Missing:   {missing}")
    print(f"Output:    {OUTPUT_DIR}")
    print(f"Catalog:   {CATALOG}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
