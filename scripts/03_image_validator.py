#!/usr/bin/env python3
"""
VX Walls — Deep Image Validator

Validates downloaded wallpaper samples before they can enter the final library.
This step is intentionally independent of license screening.

Checks:
- file integrity / decodability
- actual image format (not extension alone)
- pixel dimensions
- file size
- extreme aspect ratios
- minimum usable pixel area
- animated-image rejection
- alpha-channel reporting
- duplicate SHA-256

Input:
    candidates/images/

Output:
    candidates/image_validation.json
    candidates/validated/  (copies of technically valid samples)

Environment variables:
    VX_INPUT_DIR       default candidates/images
    VX_OUTPUT          default candidates/image_validation.json
    VX_VALIDATED_DIR   default candidates/validated
    VX_MIN_WIDTH       default 1080
    VX_MIN_HEIGHT      default 1080
    VX_MIN_BYTES       default 150000
    VX_MAX_BYTES       default 20000000
    VX_MIN_PIXELS      default 2000000
    VX_MIN_RATIO       default 0.50
    VX_MAX_RATIO       default 2.20
    VX_ALLOW_SQUARE    default 1

Dependencies:
    pip install pillow
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
from pathlib import Path
from typing import Any

from PIL import Image, UnidentifiedImageError

INPUT_DIR = Path(os.getenv("VX_INPUT_DIR", "candidates/images"))
OUTPUT = Path(os.getenv("VX_OUTPUT", "candidates/image_validation.json"))
VALIDATED_DIR = Path(os.getenv("VX_VALIDATED_DIR", "candidates/validated"))
MIN_WIDTH = int(os.getenv("VX_MIN_WIDTH", "1080"))
MIN_HEIGHT = int(os.getenv("VX_MIN_HEIGHT", "1080"))
MIN_BYTES = int(os.getenv("VX_MIN_BYTES", "150000"))
MAX_BYTES = int(os.getenv("VX_MAX_BYTES", "20000000"))
MIN_PIXELS = int(os.getenv("VX_MIN_PIXELS", "2000000"))
MIN_RATIO = float(os.getenv("VX_MIN_RATIO", "0.50"))
MAX_RATIO = float(os.getenv("VX_MAX_RATIO", "2.20"))
ALLOW_SQUARE = os.getenv("VX_ALLOW_SQUARE", "1") == "1"

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate(path: Path) -> tuple[bool, dict[str, Any]]:
    size = path.stat().st_size
    result: dict[str, Any] = {
        "file": path.name,
        "path": path.as_posix(),
        "bytes": size,
        "sha256": None,
        "format": None,
        "width": None,
        "height": None,
        "pixels": None,
        "aspect_ratio": None,
        "orientation": None,
        "animated": False,
        "has_alpha": False,
        "decision": "reject",
        "reason": None,
    }

    if path.suffix.lower() not in EXTENSIONS:
        result["reason"] = "unsupported_extension"
        return False, result

    if size < MIN_BYTES:
        result["reason"] = f"too_small_bytes:{size}"
        return False, result
    if size > MAX_BYTES:
        result["reason"] = f"too_large_bytes:{size}"
        return False, result

    result["sha256"] = sha256(path)

    try:
        with Image.open(path) as image:
            image.verify()

        with Image.open(path) as image:
            width, height = image.size
            fmt = (image.format or "").upper()
            frames = getattr(image, "n_frames", 1)
            animated = frames > 1
            mode = image.mode
            has_alpha = "A" in mode or "transparency" in image.info
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        result["reason"] = f"invalid_image:{exc}"
        return False, result

    result.update({
        "format": fmt,
        "width": width,
        "height": height,
        "pixels": width * height,
        "aspect_ratio": round(width / height, 4),
        "orientation": "portrait" if height > width else "landscape" if width > height else "square",
        "animated": animated,
        "has_alpha": has_alpha,
    })

    if animated:
        result["reason"] = "animated_image"
        return False, result
    if width < MIN_WIDTH or height < MIN_HEIGHT:
        result["reason"] = f"dimensions_below_minimum:{width}x{height}"
        return False, result
    if width * height < MIN_PIXELS:
        result["reason"] = f"pixel_area_below_minimum:{width * height}"
        return False, result

    ratio = width / height
    if not (MIN_RATIO <= ratio <= MAX_RATIO):
        result["reason"] = f"wallpaper_ratio_out_of_range:{ratio:.4f}"
        return False, result

    if not ALLOW_SQUARE and width == height:
        result["reason"] = "square_not_allowed"
        return False, result

    result["decision"] = "technical_pass"
    result["reason"] = "all_technical_checks_passed"
    return True, result


def main() -> int:
    if not INPUT_DIR.exists():
        print(f"Input directory not found: {INPUT_DIR}")
        return 2

    VALIDATED_DIR.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, Any]] = []
    seen_hashes: set[str] = set()

    for path in sorted(INPUT_DIR.iterdir()):
        if not path.is_file() or path.suffix.lower() not in EXTENSIONS:
            continue

        ok, record = validate(path)
        if ok and record["sha256"] in seen_hashes:
            record["decision"] = "reject"
            record["reason"] = "duplicate_content"
            ok = False

        if ok:
            seen_hashes.add(record["sha256"])
            shutil.copy2(path, VALIDATED_DIR / path.name)

        records.append(record)

    summary = {
        "total": len(records),
        "technical_pass": sum(r["decision"] == "technical_pass" for r in records),
        "rejected": sum(r["decision"] == "reject" for r in records),
        "duplicates": sum(r["reason"] == "duplicate_content" for r in records),
        "animated": sum(r["reason"] == "animated_image" for r in records),
    }

    payload = {
        "generated_by": "VX Walls Deep Image Validator 1.0",
        "note": "Technical validation only. A technical pass does not grant copyright or redistribution rights.",
        "filters": {
            "min_width": MIN_WIDTH,
            "min_height": MIN_HEIGHT,
            "min_bytes": MIN_BYTES,
            "max_bytes": MAX_BYTES,
            "min_pixels": MIN_PIXELS,
            "min_ratio": MIN_RATIO,
            "max_ratio": MAX_RATIO,
            "allow_square": ALLOW_SQUARE,
        },
        "summary": summary,
        "records": records,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    print("VX Walls image validation complete")
    print(json.dumps(summary, indent=2))
    print(f"Report: {OUTPUT}")
    print(f"Validated samples: {VALIDATED_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
