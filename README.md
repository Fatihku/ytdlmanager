# YTDL Manager

**Description:** A native macOS GUI for yt-dlp

**Developer:** Fatih Kuyucuoglu

**GitHub:** https://github.com/Fatihku/ytdlmanager

**Version:** 1.3.1

**Release Date:** 2026-04-20

## Requirements
- macOS 13+
- yt-dlp installed

## Installation
To install yt-dlp, open Terminal and run:

```bash
brew install yt-dlp
```

## Find yt-dlp path
Run:

```bash
which yt-dlp
```

## Supported sites
- YouTube
- TikTok
- Instagram
- Twitter/X
- Reddit

## Supported formats
- MP4
- MKV
- MP3
- AAC

## Supported qualities
- Best
- 1080p
- 720p
- 480p

## Features built so far
- Multi-URL input for batch downloads
- Format selection: MP4, MKV, MP3, AAC
- Quality selection: Best, 1080p, 720p, 480p
- Download folder selector
- Download progress indicators
- Active download history list
- Retry failed downloads and reveal completed files in Finder
- Settings sheet with yt-dlp path and download folder persistence
- App icon support for macOS
- Version watermark in the app footer
- About links for yt-dlp and YTDL Manager on GitHub

## Changelog
### v1.3.1 - 20.04.2026
- Added: copy buttons (doc.on.doc) next to title, channel, and URL in history rows
- Added: channel @handle display as "Name • @handle" in history rows
- Added: daily sequence number in filename prefix (e.g. 2026-04-20-01, increments per day)
- Added: "Add to List" button on history rows to send URL back to the Download tab
- Improved: hover effects on all history row buttons (pointing hand cursor, copy button highlight)

### v1.3.0 - 20.04.2026
- Added: uploader/channel name captured from yt-dlp and displayed in history rows
- Added: platform badge (YT/TK/IG/TW/RD/?) with platform color next to each history entry
- Added: date format changed to DD.MM.YYYY across the History tab
- Added: Redownload button on each history row to re-run with the same format and quality

### v1.2.0 - 20.04.2026
- Fixed: filename rename now appends numeric suffix when a duplicate exists
- Fixed: history list clipping and renamed item visibility
- Fixed: emoji and date-prefix options behave correctly during rename

### v1.1.0 - 2026-04-20
- Fixed: ffmpeg path corrected to /usr/local/bin/ffmpeg
- Fixed: MP4 merge now works correctly with audio

### v1.0.0 - 2026-04-20
- Added: macOS SwiftUI download manager app with multi-URL input
- Added: format and quality selection
- Added: download folder selection and settings persistence
- Added: active download progress and cancel support
- Added: download history with retry and folder actions
- Added: app icon and version watermark
- Added: About links and README documentation

## Links
- yt-dlp project: https://github.com/yt-dlp/yt-dlp

## License
MIT
