#!/usr/bin/env python3
"""
VX Walls — License Gate

Reads candidates/candidates.json and applies a conservative license policy.
This is a screening tool, not legal advice and not a substitute for reading
individual repository/file license terms.

Policy:
- Explicit permissive SPDX licenses can pass the automated gate.
- Public-domain style licenses can pass the automated gate.
- Copyleft licenses are flagged for manual review rather than silently rejected.
- Unknown/no license evidence is rejected.
- The original file URL and repository are preserved for auditability.

Usage:
    python scripts/02_license_check.py

Environment variables:
    VX_INPUT   Input candidates JSON (default: candidates/candidates.json)
    VX_OUTPUT  Output license report (default: candidates/license_report.json)
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

INPUT = Path(os.getenv("VX_INPUT", "candidates/candidates.json"))
OUTPUT = Path(os.getenv("VX_OUTPUT", "candidates/license_report.json"))

# Conservative allow-list for automated screening. Presence of an SPDX ID
# alone is not a legal determination: the file itself may have extra terms,
# and the repository license may not cover every image in the repository.
PERMISSIVE = {
    "MIT",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "ISC",
    "0BSD",
    "CC0-1.0",
    "Unlicense",
    "WTFPL",
    "Zlib",
}

# These can be compatible with redistribution, but require manual review
# because attribution/share-alike/source obligations may matter for the app.
MANUAL_REVIEW = {
    "CC-BY-4.0",
    "CC-BY-3.0",
    "CC-BY-2.0",
    "CC-BY-SA-4.0",
    "CC-BY-SA-3.0",
    "CC-BY-SA-2.0",
    "MPL-2.0",
    "Apache-2.0",
    "GPL-3.0",
    "GPL-2.0",
    "LGPL-3.0",
    "LGPL-2.1",
}


def classify(record: dict[str, Any]) -> tuple[str, str]:
    if record.get("status") != "accepted_for_review":
        return "reject", "technical_screen_failed"

    license_id = str(record.get("license_spdx_id") or "").strip()
    license_name = str(record.get("license_name") or "").strip()

    if not license_id:
        return "reject", "license_unclear"

    if license_id in PERMISSIVE:
        return "pass_automated", "permissive_license_metadata"

    if license_id in MANUAL_REVIEW:
        return "manual_review", f"license_requires_review:{license_id}"

    return "manual_review", f"unrecognized_license:{license_id or license_name}"


def main() -> int:
    if not INPUT.exists():
        print(f"ERROR: input not found: {INPUT}")
        return 2

    payload = json.loads(INPUT.read_text(encoding="utf-8"))
    candidates = payload.get("candidates", [])
    if not isinstance(candidates, list):
        print("ERROR: candidates must be a list")
        return 2

    report: list[dict[str, Any]] = []
    for item in candidates:
        if not isinstance(item, dict):
            continue
        decision, reason = classify(item)
        report.append({
            "decision": decision,
            "reason": reason,
            "repository": item.get("repository"),
            "path": item.get("path"),
            "html_url": item.get("html_url"),
            "raw_url": item.get("raw_url"),
            "license_spdx_id": item.get("license_spdx_id"),
            "license_name": item.get("license_name"),
            "sha256": item.get("sha256"),
            "width": item.get("width"),
            "height": item.get("height"),
        })

    summary = {
        "total": len(report),
        "pass_automated": sum(x["decision"] == "pass_automated" for x in report),
        "manual_review": sum(x["decision"] == "manual_review" for x in report),
        "reject": sum(x["decision"] == "reject" for x in report),
    }

    output = {
        "generated_by": "VX Walls License Gate 1.0",
        "policy": {
            "note": "Automated screening only; individual file rights and provider terms still require review.",
            "permissive_spdx_allowlist": sorted(PERMISSIVE),
            "manual_review_spdx": sorted(MANUAL_REVIEW),
        },
        "summary": summary,
        "records": report,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(output, indent=2, ensure_ascii=False), encoding="utf-8")

    print("VX Walls license screening complete")
    print(json.dumps(summary, indent=2))
    print(f"Report: {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
