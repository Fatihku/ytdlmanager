# YTDL Manager

A native macOS app built with SwiftUI.
A native Mac GUI for yt-dlp.

## Project Structure
- `YTDL Manager/ContentView.swift` — main screen
- `YTDL Manager/YTDL_ManagerApp.swift` — app entry point

## Rules
- Use Swift and SwiftUI, do not use UIKit
- Target macOS 13+
- Run yt-dlp using Process()
- Save settings with UserDefaults
- Use only English in the project
- Write comments in English
- Keep each view in a separate file

## Features
- Multi-URL input
- Format selection: MP4, MKV, MP3, AAC
- Quality selection: Best, 1080p, 720p, 480p
- Download folder selection
- Progress indicators
- Download history

## Git Rules
- Commit after every meaningful change
- Commit messages must follow Conventional Commits format:
  - feat: new feature
  - fix: bug fix
  - refactor: code cleanup
  - chore: maintenance
- Push each commit to the remote
- Check changes with git status before committing

## Versioning & Release Notes
- Every time a new version is built, update README.md with:
  - Version number
  - Release date
  - List of changes made in this version (what was added, fixed, improved)
- Keep a changelog section in README.md with all previous versions listed
- Format:
  ## Changelog
  ### v1.0.1 - 2026-04-20
  - Added: ...
  - Fixed: ...
  - Improved: ...
