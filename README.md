# Simple Live Wallpaper

A lightweight macOS menu bar app for turning local videos into live desktop wallpapers. It lets you import a video, optionally optimize it, and keep the selected wallpaper running quietly behind your desktop icons.

## Features

- Runs purely in the menu bar 
- Video wallpaper playback across connected displays
- Import and convert common video formats to HEVC `.mp4`
- Frame-rate choice during conversion for better power control
- Remembers the last active wallpaper
- Saves a static first frame as the desktop/lock-screen fallback image
- Sandboxed file access using security-scoped bookmarks

## Requirements

- macOS 13.0 or later

## Download

Download the latest `.dmg` from the [Releases page](https://github.com/Ganeev-S/macOS-Live-Wallpaper/releases).

> **Note:** This app is currently unsigned and not notarized by Apple, so macOS Gatekeeper will block it by default. See below for how to open it anyway.

## Installing on macOS

Because the app isn't signed with an Apple Developer certificate, macOS will show a warning like *"Simple Live Wallpaper" can't be opened because it is from an unidentified developer* or *Apple could not verify "Simple Live Wallpaper" is free of malware*.

To open it anyway:

1. Open the `.dmg` and drag **Simple Live Wallpaper.app** into your **Applications** folder.
2. Try to open the app normally — you'll likely see the warning dialog. Click **Done** or **Cancel** to dismiss it.
3. Go to **System Settings → Privacy & Security**, scroll down to the Security section, and you should see a message about "Simple Live Wallpaper" being blocked. Click **Open Anyway**.
4. Confirm in the next dialog by clicking **Open**.

Alternatively, you can remove the quarantine flag via Terminal:

```sh
xattr -d com.apple.quarantine "/Applications/Simple Live Wallpaper.app"
```

After either of these, the app will open normally on future launches.

## Running From Source

1. Open `Simple Live Wallpaper.xcodeproj` in Xcode.
2. Select the `Simple Live Wallpaper` scheme.
3. Build and run.
4. Use the menu bar icon to choose a wallpaper folder, import a video, or select an existing converted wallpaper.

The app stores generated wallpapers in the folder you choose. If no folder has been selected yet, it falls back to Application Support.

## Building Your Own DMG

For a local release build:

1. In Xcode, choose `Product > Archive`.
2. Export the archive as a macOS app.
3. Use `scripts/make-dmg.sh` to wrap the exported `.app` in a DMG:

```sh
sh scripts/make-dmg.sh "/path/to/Simple Live Wallpaper.app"
```

Unsigned builds can still be shared for testing, but macOS Gatekeeper will warn users as described above. For a public release without that warning, sign and notarize the app with an Apple Developer account before distributing the DMG.

## Repository Notes

This project was built with substantial AI-assisted iteration. The current code has been organized around the final app behavior: menu bar control, wallpaper playback, import/conversion, security-scoped storage, and lock-screen fallback handling.
