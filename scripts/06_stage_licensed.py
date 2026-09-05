#!/usr/bin/env python3
"""
VX Walls — License-approved staging gate

Copies only images that passed the automated license gate AND technical
validation into a clean staging directory for optimization.

This prevents technically valid but unlicensed/unclear candidates from ever
entering the publishable wallpaper tree.

Inputs:
    candidates/license_report.json
    candidates/validated/

Output:
    candidates/approved/

Environment variables:
    VX_LICENSE_REPORT   default candidates/license_report.json
    VX_VALIDATED_DIR    default candidates/validated
    VX_APPROVED_DIR     default candidates/approved
"""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any

REPORT = Path(os.getenv("VX_LICENSE_REPORT", "candidates/license_report.json"))
VALIDATED_DIR = Path(os.getenv("VX_VALIDATED_DIR", "candidates/validated"))
APPROVED_DIR = Path(os.getenv("VX_APPROVED_DIR", "candidates/approved"))


def main() -> int:
    if not REPORT.exists():
        print(f"ERROR: license report not found: {REPORT}")
        return 2
    if not VALIDATED_DIR.exists():
        print(f"ERROR: validated directory not found: {VALIDATED_DIR}")
        return 2

    payload: dict[str, Any] = json.loads(REPORT.read_text(encoding="utf-8"))
    records = payload.get("records", [])
    if not isinstance(records, list):
        print("ERROR: license report records must be a list")
        return 2

    APPROVED_DIR.mkdir(parents=True, exist_ok=True)

    # Start clean so removed/rejected candidates cannot remain published from
    # an earlier run.
    for path in APPROVED_DIR.iterdir():
        if path.is_file():
            path.unlink()

    approved = 0
    missing = 0
    for record in records:
        if not isinstance(record, dict):
            continue
        if record.get("decision") != "pass_automated":
            continue

        filename = Path(str(record.get("html_url") or "")).name
        sha = str(record.get("sha256") or "")
        # The finder names downloaded files with the source stem + SHA prefix.
        # Match by the recorded SHA rather than trusting a source filename.
        source = None
        for candidate in VALIDATED_DIR.iterdir():
            if not candidate.is_file():
                continue
            if sha and sha[:10] in candidate.name:
                source = candidate
                break

        if source is None:
            missing += 1
            continue

        shutil.copy2(source, APPROVED_DIR / source.name)
        approved += 1

    summary = {
        "license_passed_staged": approved,
        "missing_technical_file": missing,
        "manual_review_excluded": sum(
            1 for r in records if isinstance(r, dict) and r.get("decision") == "manual_review"
        ),
        "rejected_excluded": sum(
            1 for r in records if isinstance(r, dict) and r.get("decision") == "reject"
        ),
    }

    print("VX Walls approved staging complete")
    print(json.dumps(summary, indent=2))
    print(f"Approved samples: {APPROVED_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
