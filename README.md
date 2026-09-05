# VX Walls Data

Curated wallpaper data pipeline for VX Walls.

## Pipeline

1. `scripts/01_github_wall_finder.py` — discover GitHub-hosted image candidates.
2. `scripts/02_license_check.py` — conservative license screening.
3. `scripts/03_image_validator.py` — technical image validation.
4. `scripts/04_optimize_webp.py` — create efficient WebP derivatives.
5. `scripts/05_build_catalog.py` — build the app-facing `wallpapers.json`.

## Important rights rule

A GitHub repository being public does **not** mean its images are free to redistribute. Every final wallpaper needs evidence that the applicable license permits the intended use. Automated checks are screening tools only and are not legal advice.

Only assets that pass the complete curation pipeline should be published in the app-facing collection.

## Suggested directories

- `scripts/` — pipeline scripts
- `candidates/` — discovery, review and validation artifacts
- `wallpapers/optimized/` — optimized final image derivatives
- `wallpapers.json` — app catalog

Do not commit GitHub access tokens or other secrets. Use environment variables or GitHub Actions secrets.
