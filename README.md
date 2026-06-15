# Simple Live Wallpaper

Simple Live Wallpaper is a lightweight macOS menu bar app for turning local videos into live desktop wallpapers. It lets you import a video, optionally convert it to HEVC at a chosen frame rate, and keep the selected wallpaper running quietly behind your desktop icons.

## Features

- Menu bar workflow with no Dock icon
- Video wallpaper playback across connected displays
- Import and convert common video formats to HEVC `.mp4`
- Frame-rate choice during conversion for better power control
- Remembers the last active wallpaper
- Saves a static first frame as the desktop/lock-screen fallback image
- Sandboxed file access using security-scoped bookmarks

## Requirements

- macOS 13.0 or later
- Xcode for building and exporting the app

## Running Locally

1. Open `Simple Live Wallpaper.xcodeproj` in Xcode.
2. Select the `Simple Live Wallpaper` scheme.
3. Build and run.
4. Use the menu bar icon to choose a wallpaper folder, import a video, or select an existing converted wallpaper.

The app stores generated wallpapers in the folder you choose. If no folder has been selected yet, it falls back to Application Support.

## Packaging

For a local release build:

1. In Xcode, choose `Product > Archive`.
2. Export the archive as a macOS app.
3. Use `scripts/make-dmg.sh` to wrap the exported `.app` in a DMG:

```sh
sh scripts/make-dmg.sh "/path/to/Simple Live Wallpaper.app"
```

Unsigned builds can still be shared for testing, but macOS Gatekeeper will warn users. For a public release, sign and notarize the app with an Apple Developer account before distributing the DMG.

## Repository Notes

This project was built with substantial AI-assisted iteration. The current code has been organized around the final app behavior: menu bar control, wallpaper playback, import/conversion, security-scoped storage, and lock-screen fallback handling.
