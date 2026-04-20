# YTDL Manager

**Description:** A native macOS GUI for yt-dlp

**Developer:** Fatih Kuyucuoglu

**GitHub:** https://github.com/Fatihku/ytdlmanager

**Version:** 1.0.0

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
