#!/usr/bin/env python3
"""
VX Walls — Wallpaper Catalog Builder

Builds the app-facing wallpapers.json from optimized wallpaper files and the
technical validation report. No license is inferred here; only records that
have already passed the upstream gates should be included.

Input:
    wallpapers/optimized/
    candidates/image_validation.json
    candidates/license_report.json (optional but recommended)

Output:
    wallpapers.json

The catalog contains dimensions, orientation, aspect ratio, category,
relative asset path and source/audit references where available.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

OPTIMIZED_DIR = Path(os.getenv("VX_OPTIMIZED_DIR", "wallpapers/optimized"))
IMAGE_REPORT = Path(os.getenv("VX_IMAGE_REPORT", "candidates/image_validation.json"))
LICENSE_REPORT = Path(os.getenv("VX_LICENSE_REPORT", "candidates/license_report.json"))
OUTPUT = Path(os.getenv("VX_CATALOG", "wallpapers.json"))


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return default


def category_for(name: str) -> str:
    # Deterministic fallback only. A later metadata/editorial step can replace
    # this with curated categories without changing the catalog schema.
    lowered = name.lower()
    for keyword, category in (
        ("nature", "Nature"),
        ("forest", "Nature"),
        ("mountain", "Nature"),
        ("space", "Space"),
        ("galaxy", "Space"),
        ("city", "City"),
        ("urban", "City"),
        ("minimal", "Minimal"),
        ("abstract", "Abstract"),
    ):
        if keyword in lowered:
            return category
    return "All"


def main() -> int:
    if not OPTIMIZED_DIR.exists():
        print(f"Optimized directory not found: {OPTIMIZED_DIR}")
        return 2

    image_payload = load_json(IMAGE_REPORT, {})
    image_records = image_payload.get("records", []) if isinstance(image_payload, dict) else []
    image_by_name = {
        str(r.get("file")): r
        for r in image_records
        if isinstance(r, dict) and r.get("decision") == "technical_pass"
    }

    license_payload = load_json(LICENSE_REPORT, {})
    license_records = license_payload.get("records", []) if isinstance(license_payload, dict) else []
    license_by_hash = {
        str(r.get("sha256")): r
        for r in license_records
        if isinstance(r, dict) and r.get("decision") == "pass_automated"
    }

    walls: list[dict[str, Any]] = []
    for file in sorted(OPTIMIZED_DIR.glob("*.webp")):
        # The optimizer preserves the source stem, so the validation report
        # normally maps directly. If metadata is unavailable, don't invent
        # dimensions; leave the record out until the validator is rerun.
        matches = [r for name, r in image_by_name.items() if Path(name).stem == file.stem]
        if not matches:
            continue
        meta = matches[0]

        source_hash = meta.get("sha256")
        license_meta = license_by_hash.get(str(source_hash))

        # A catalog entry must have upstream license approval. Manual-review
        # records are intentionally excluded from the app-facing catalog.
        if LICENSE_REPORT.exists() and license_meta is None:
            continue

        width = meta.get("width")
        height = meta.get("height")
        if not isinstance(width, int) or not isinstance(height, int) or height <= 0:
            continue

        walls.append({
            "id": file.stem,
            "category": category_for(file.name),
            "url": f"wallpapers/optimized/{file.name}",
            "width": width,
            "height": height,
            "aspect_ratio": round(width / height, 4),
            "orientation": meta.get("orientation"),
            "format": "webp",
            "bytes": file.stat().st_size,
            "source": {
                "repository": license_meta.get("repository") if license_meta else None,
                "path": license_meta.get("path") if license_meta else None,
                "html_url": license_meta.get("html_url") if license_meta else None,
                "license_spdx_id": license_meta.get("license_spdx_id") if license_meta else None,
                "sha256": source_hash,
            },
        })

    catalog = {
        "schema_version": 1,
        "generated_by": "VX Walls Catalog Builder 1.0",
        "count": len(walls),
        "wallpapers": walls,
    }

    OUTPUT.write_text(json.dumps(catalog, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Catalog built: {OUTPUT}")
    print(f"Wallpapers: {len(walls)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
