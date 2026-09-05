#!/usr/bin/env python3
"""
VX Walls — GitHub Wallpaper Finder

Discovers image files indexed by GitHub code search, downloads small samples,
checks basic image quality, and writes a reviewable candidates.json file.

IMPORTANT:
- A public GitHub image is NOT automatically licensed for redistribution.
- This script only marks a repository as "license_evidence_found" when GitHub
  exposes repository license metadata. It does not make a legal determination.
- Unclear-license candidates are never copied into the final wallpapers folder.

Usage:
    export GITHUB_TOKEN="..."
    python scripts/01_github_wall_finder.py

Optional environment variables:
    VX_SEARCH_LIMIT       Maximum search results per query (default: 20)
    VX_MIN_WIDTH          Minimum width in pixels (default: 1080)
    VX_MIN_HEIGHT         Minimum height in pixels (default: 1080)
    VX_MIN_BYTES          Minimum file size (default: 150000)
    VX_MAX_BYTES          Maximum file size (default: 20000000)
    VX_OUTPUT             Output JSON path (default: candidates/candidates.json)
    VX_DOWNLOAD_DIR       Accepted samples directory (default: candidates/images)
    VX_ALLOW_UNKNOWN_LICENSES
                           Set to 1 only for discovery/testing. Default: 0

Dependencies:
    pip install requests pillow
"""

from __future__ import annotations

import hashlib
import io
import json
import os
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import quote

import requests
from PIL import Image

GITHUB_API = "https://api.github.com"
SEARCH_QUERIES = [
    "wallpaper extension:jpg",
    "wallpaper extension:jpeg",
    "wallpaper extension:png",
    "wallpaper extension:webp",
    "phone wallpaper extension:jpg",
    "phone wallpaper extension:jpeg",
    "phone wallpaper extension:png",
    "phone wallpaper extension:webp",
    "mobile wallpaper extension:jpg",
    "mobile wallpaper extension:webp",
    "minimal wallpaper extension:jpg",
    "minimal wallpaper extension:webp",
    "nature wallpaper extension:jpg",
    "nature wallpaper extension:webp",
    "abstract wallpaper extension:jpg",
    "abstract wallpaper extension:webp",
]

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
REPO_LICENSE_URL = re.compile(r"https?://api\.github\.com/repos/[^/]+/[^/]+/license")


def env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


SEARCH_LIMIT = env_int("VX_SEARCH_LIMIT", 20)
MIN_WIDTH = env_int("VX_MIN_WIDTH", 1080)
MIN_HEIGHT = env_int("VX_MIN_HEIGHT", 1080)
MIN_BYTES = env_int("VX_MIN_BYTES", 150_000)
MAX_BYTES = env_int("VX_MAX_BYTES", 20_000_000)
ALLOW_UNKNOWN_LICENSES = os.getenv("VX_ALLOW_UNKNOWN_LICENSES", "0") == "1"
OUTPUT = Path(os.getenv("VX_OUTPUT", "candidates/candidates.json"))
DOWNLOAD_DIR = Path(os.getenv("VX_DOWNLOAD_DIR", "candidates/images"))


class GitHubClient:
    def __init__(self, token: str) -> None:
        self.session = requests.Session()
        self.session.headers.update(
            {
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "VX-Walls-Wall-Finder/1.0",
                "Authorization": f"Bearer {token}",
            }
        )
        self.license_cache: dict[str, dict[str, Any] | None] = {}

    def get(self, url: str, **kwargs: Any) -> requests.Response:
        response = self.session.get(url, timeout=30, **kwargs)
        response.raise_for_status()
        return response

    def search_code(self, query: str) -> list[dict[str, Any]]:
        response = self.get(
            f"{GITHUB_API}/search/code",
            params={"q": query, "per_page": SEARCH_LIMIT},
        )
        payload = response.json()
        return payload.get("items", [])

    def repo_license(self, full_name: str) -> dict[str, Any] | None:
        if full_name in self.license_cache:
            return self.license_cache[full_name]

        try:
            response = self.get(f"{GITHUB_API}/repos/{full_name}")
            license_info = response.json().get("license")
            if isinstance(license_info, dict):
                self.license_cache[full_name] = license_info
                return license_info
        except requests.RequestException:
            pass

        self.license_cache[full_name] = None
        return None

    def download(self, raw_url: str) -> tuple[bytes, str] | None:
        try:
            with self.session.get(
                raw_url,
                stream=True,
                timeout=30,
                allow_redirects=True,
            ) as response:
                response.raise_for_status()
                content_type = response.headers.get("content-type", "")
                content_length = response.headers.get("content-length")
                if content_length and int(content_length) > MAX_BYTES:
                    return None

                data = bytearray()
                for chunk in response.iter_content(chunk_size=256 * 1024):
                    if not chunk:
                        continue
                    data.extend(chunk)
                    if len(data) > MAX_BYTES:
                        return None
                return bytes(data), content_type
        except (requests.RequestException, ValueError):
            return None


def raw_github_url(full_name: str, branch: str, path: str) -> str:
    owner, repo = full_name.split("/", 1)
    return f"https://raw.githubusercontent.com/{owner}/{repo}/{quote(branch, safe='/-')}/{quote(path, safe='/') }"


def safe_filename(full_name: str, path: str, digest: str) -> str:
    stem = Path(path).stem
    stem = re.sub(r"[^A-Za-z0-9._-]+", "_", stem).strip("._") or "wallpaper"
    owner_repo = re.sub(r"[^A-Za-z0-9._-]+", "_", full_name)
    return f"{owner_repo}_{stem}_{digest[:10]}.webp"


def classify_aspect(width: int, height: int) -> str:
    ratio = width / height
    if ratio >= 1.55:
        return "landscape"
    if ratio <= 0.72:
        return "portrait"
    return "square_or_moderate"


def validate_image(data: bytes) -> dict[str, Any]:
    if len(data) < MIN_BYTES:
        raise ValueError(f"too_small_bytes:{len(data)}")

    with Image.open(io.BytesIO(data)) as image:
        image.verify()

    with Image.open(io.BytesIO(data)) as image:
        width, height = image.size
        fmt = (image.format or "").lower()

    if width < MIN_WIDTH or height < MIN_HEIGHT:
        raise ValueError(f"too_small_dimensions:{width}x{height}")

    if width / height > 3.2 or height / width > 3.2:
        raise ValueError(f"extreme_aspect_ratio:{width}x{height}")

    return {
        "width": width,
        "height": height,
        "format": fmt,
        "aspect_ratio": round(width / height, 4),
        "orientation": classify_aspect(width, height),
    }


def main() -> int:
    token = os.getenv("GITHUB_TOKEN")
    if not token:
        print("ERROR: GITHUB_TOKEN is required.", file=sys.stderr)
        return 2

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)

    client = GitHubClient(token)
    candidates: list[dict[str, Any]] = []
    seen_file_urls: set[str] = set()
    seen_content_hashes: set[str] = set()

    print(f"Searching GitHub with {len(SEARCH_QUERIES)} queries...")

    for query in SEARCH_QUERIES:
        try:
            items = client.search_code(query)
        except requests.RequestException as exc:
            print(f"WARN search failed: {query!r}: {exc}", file=sys.stderr)
            continue

        print(f"  {query}: {len(items)} results")

        for item in items:
            repo = item.get("repository") or {}
            full_name = repo.get("full_name")
            path = item.get("path")
            if not full_name or not path:
                continue

            ext = Path(path).suffix.lower()
            if ext not in IMAGE_EXTENSIONS:
                continue

            default_branch = repo.get("default_branch") or "main"
            html_url = item.get("html_url") or ""
            raw_url = raw_github_url(full_name, default_branch, path)
            if raw_url in seen_file_urls:
                continue
            seen_file_urls.add(raw_url)

            license_info = client.repo_license(full_name)
            license_id = license_info.get("spdx_id") if license_info else None
            license_name = license_info.get("name") if license_info else None
            license_state = "license_evidence_found" if license_info else "license_unclear"

            record: dict[str, Any] = {
                "status": "pending",
                "query": query,
                "repository": full_name,
                "path": path,
                "html_url": html_url,
                "raw_url": raw_url,
                "default_branch": default_branch,
                "license_state": license_state,
                "license_spdx_id": license_id,
                "license_name": license_name,
            }

            if license_state == "license_unclear" and not ALLOW_UNKNOWN_LICENSES:
                record["status"] = "rejected"
                record["reason"] = "license_unclear"
                candidates.append(record)
                continue

            downloaded = client.download(raw_url)
            if not downloaded:
                record["status"] = "rejected"
                record["reason"] = "download_failed_or_too_large"
                candidates.append(record)
                continue

            data, content_type = downloaded
            record["content_type"] = content_type
            record["bytes"] = len(data)

            try:
                image_meta = validate_image(data)
            except (ValueError, OSError) as exc:
                record["status"] = "rejected"
                record["reason"] = str(exc)
                candidates.append(record)
                continue

            digest = hashlib.sha256(data).hexdigest()
            record["sha256"] = digest
            record.update(image_meta)

            if digest in seen_content_hashes:
                record["status"] = "rejected"
                record["reason"] = "duplicate_content"
                candidates.append(record)
                continue

            seen_content_hashes.add(digest)
            filename = safe_filename(full_name, path, digest)
            sample_path = DOWNLOAD_DIR / filename
            sample_path.write_bytes(data)

            record["status"] = "accepted_for_review"
            record["local_sample"] = str(sample_path.as_posix())
            candidates.append(record)

    summary = {
        "total": len(candidates),
        "accepted_for_review": sum(1 for x in candidates if x["status"] == "accepted_for_review"),
        "rejected": sum(1 for x in candidates if x["status"] == "rejected"),
        "license_unclear": sum(1 for x in candidates if x.get("reason") == "license_unclear"),
        "duplicate_content": sum(1 for x in candidates if x.get("reason") == "duplicate_content"),
    }

    payload = {
        "generated_by": "VX Walls GitHub Wall Finder 1.0",
        "notes": [
            "Discovery only: GitHub-hosted images require individual rights review before redistribution.",
            "accepted_for_review means the image passed technical checks and has repository license metadata; it is not a legal approval.",
            "Run the license-validation step before moving anything into the final wallpapers directory.",
        ],
        "filters": {
            "min_width": MIN_WIDTH,
            "min_height": MIN_HEIGHT,
            "min_bytes": MIN_BYTES,
            "max_bytes": MAX_BYTES,
            "allow_unknown_licenses": ALLOW_UNKNOWN_LICENSES,
        },
        "summary": summary,
        "candidates": candidates,
    }

    OUTPUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    print("\nDone.")
    print(json.dumps(summary, indent=2))
    print(f"Catalog: {OUTPUT}")
    print(f"Samples: {DOWNLOAD_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
