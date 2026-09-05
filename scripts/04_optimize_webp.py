#!/usr/bin/env python3
"""VX Walls — Wallpaper Optimizer.

Converts approved images to efficient WebP derivatives. The output directory
is rebuilt each run so removed/rejected candidates cannot remain published.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path
from PIL import Image, UnidentifiedImageError

INPUT_DIR = Path(os.getenv("VX_INPUT_DIR", "candidates/validated"))
OUTPUT_DIR = Path(os.getenv("VX_OUTPUT_DIR", "wallpapers/optimized"))
MAX_LONG_EDGE = int(os.getenv("VX_MAX_LONG_EDGE", "3200"))
QUALITY = int(os.getenv("VX_WEBP_QUALITY", "88"))
ALLOW_LARGER = os.getenv("VX_ALLOW_LARGER", "0") == "1"
EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def resize_without_upscale(image: Image.Image) -> Image.Image:
    width, height = image.size
    longest = max(width, height)
    if longest <= MAX_LONG_EDGE:
        return image.copy()
    scale = MAX_LONG_EDGE / longest
    return image.resize(
        (round(width * scale), round(height * scale)),
        Image.Resampling.LANCZOS,
    )


def main() -> int:
    if not INPUT_DIR.exists():
        print(f"Input directory not found: {INPUT_DIR}")
        return 2

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUTPUT_DIR.iterdir():
        if old.is_file() or old.is_symlink():
            old.unlink()
        elif old.is_dir():
            shutil.rmtree(old)

    converted = 0
    skipped = 0

    for source in sorted(INPUT_DIR.iterdir()):
        if not source.is_file() or source.suffix.lower() not in EXTENSIONS:
            continue
        try:
            with Image.open(source) as opened:
                opened.load()
                has_alpha = "A" in opened.mode or "transparency" in opened.info
                working = opened.convert("RGBA" if has_alpha else "RGB")
                optimized = resize_without_upscale(working)
                output = OUTPUT_DIR / f"{source.stem}.webp"
                optimized.save(output, format="WEBP", quality=QUALITY, method=6, lossless=False)
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            print(f"SKIP {source.name}: {exc}")
            skipped += 1
            continue

        if not ALLOW_LARGER and output.stat().st_size >= source.stat().st_size:
            output.unlink(missing_ok=True)
            print(f"SKIP {source.name}: WebP was not smaller")
            skipped += 1
            continue

        print(f"OK   {source.name} -> {output.name} ({output.stat().st_size:,} bytes)")
        converted += 1

    print(f"\nConverted: {converted}\nSkipped:   {skipped}\nOutput:    {OUTPUT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
