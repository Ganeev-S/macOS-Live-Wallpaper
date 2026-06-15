# Release Checklist

Use this checklist when you are ready to publish a GitHub release.

## Before Pushing

- Confirm the app builds and runs in Xcode.
- Test selecting a wallpaper folder.
- Test importing a short video and applying it as the wallpaper.
- Test quitting and reopening the app to confirm the last wallpaper restarts.
- Review `git status` so only intentional files are included.
- Remove any user-specific Xcode files from the commit.
- Add a license if you want other people to reuse the code.

## GitHub Repository

If this folder does not have a remote yet:

```sh
git remote add origin https://github.com/<your-username>/<repo-name>.git
git branch -M main
git push -u origin main
```

If you create the repository from GitHub's website, do not initialize it with a README or `.gitignore`; this project already has those files locally.

## DMG

After exporting the app from Xcode:

```sh
sh scripts/make-dmg.sh "/path/to/Simple Live Wallpaper.app"
```

The DMG will be written to `dist/`.

## Signing and Notarization

For portfolio sharing, an unsigned DMG is often acceptable if you explain that it is a local build. For general public downloads, use an Apple Developer account to sign and notarize the app so macOS users do not hit avoidable Gatekeeper warnings.
