#!/usr/bin/env python3
"""
VX Walls — App Asset Preparation

Creates a clean, deterministic app-serving directory from the optimized
wallpaper library and rewrites wallpapers.json with absolute raw GitHub URLs.

This is the final data-preparation step before the Flutter app consumes the
catalog. It does NOT approve copyright/licensing; upstream gates remain the
source of truth.

Input:
    wallpapers/optimized/
    wallpapers.json

Output:
    wallpapers/app/
    wallpapers.json

Environment:
    VX_RAW_BASE_URL  Base raw GitHub URL. Defaults to this repository's main
                     branch.
    VX_OUTPUT_DIR    default wallpapers/app
    VX_CATALOG       default wallpapers.json

The catalog keeps source/audit metadata while adding a stable app URL.
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
    if not OPTIMIZED_DIR.exists():
        print(f"ERROR: optimized directory not found: {OPTIMIZED_DIR}")
        return 2
    if not CATALOG.exists():
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

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    copied = 0
    missing = 0
    prepared: list[dict[str, Any]] = []

    for wall in walls:
        if not isinstance(wall, dict):
            continue
        relative = str(wall.get("url") or "")
        filename = Path(relative).name
        if not filename or Path(filename).suffix.lower() != ".webp":
            continue

        source = OPTIMIZED_DIR / filename
        if not source.is_file():
            missing += 1
            continue

        destination = OUTPUT_DIR / filename
        shutil.copy2(source, destination)
        copied += 1

        item = dict(wall)
        item["url"] = f"{RAW_BASE}/wallpapers/app/{filename}"
        item["download_url"] = item["url"]
        item["local_path"] = f"wallpapers/app/{filename}"
        prepared.append(item)

    output = {
        "schema_version": 2,
        "generated_by": "VX Walls App Asset Preparation 1.0",
        "count": len(prepared),
        "wallpapers": prepared,
    }
    CATALOG.write_text(json.dumps(output, indent=2, ensure_ascii=False), encoding="utf-8")

    print("VX Walls app assets prepared")
    print(f"Copied:  {copied}")
    print(f"Missing: {missing}")
    print(f"Output:  {OUTPUT_DIR}")
    print(f"Catalog: {CATALOG}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
