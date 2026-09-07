# VX Walls Data

Wallpaper asset library for the VX Walls app.

## Test library layout

```text
wallpapers/
├── optimized/   # put the 20–30 test wallpapers here
└── thumbs/      # optional thumbnails; not required for the first app test

wallpapers.json # app catalog
```

### First test

1. Select 20–30 test wallpapers.
2. Upload them to `wallpapers/optimized/`.
3. Build/update `wallpapers.json` so it contains those files and their dimensions.
4. Verify the raw GitHub URL for one file works.
5. Launch the VX Walls APK and refresh the Home library.

For this repository's current functional test phase, the image set is only a test corpus. Before public distribution, replace test images with assets that are cleared for redistribution.
