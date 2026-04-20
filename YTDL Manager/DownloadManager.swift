import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class DownloadManager: ObservableObject {
    @Published var downloadFolder: String
    @Published var removeEmojis: Bool {
        didSet {
            UserDefaults.standard.set(removeEmojis, forKey: Self.removeEmojisKey)
        }
    }
    @Published var prefixDate: Bool {
        didSet {
            UserDefaults.standard.set(prefixDate, forKey: Self.prefixDateKey)
        }
    }

    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var history: [DownloadItem] = []
    @Published private(set) var persistentHistory: [DownloadHistoryEntry] = []
    @Published var ytDlpPath: String

    private let persistentHistoryManager = PersistentHistoryManager()
    private static let downloadFolderKey = "YTDLManagerDownloadFolder"
    private static let ytDlpPathKey = "YTDLManagerYtDlpPath"
    private static let removeEmojisKey = "YTDLManagerRemoveEmojis"
    private static let prefixDateKey = "YTDLManagerPrefixDate"

    init() {
        let defaultFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
        self.downloadFolder = UserDefaults.standard.string(forKey: Self.downloadFolderKey) ?? defaultFolder
        let defaultYtDlpPath = "/opt/homebrew/bin/yt-dlp"
        self.ytDlpPath = UserDefaults.standard.string(forKey: Self.ytDlpPathKey) ?? defaultYtDlpPath
        self.removeEmojis = UserDefaults.standard.bool(forKey: Self.removeEmojisKey)
        self.prefixDate = UserDefaults.standard.bool(forKey: Self.prefixDateKey)
        self.persistentHistory = persistentHistoryManager.entries
    }

    func startDownloads(urls: [String], format: DownloadFormat, quality: DownloadQuality) async {
        guard !urls.isEmpty else { return }

        for rawUrl in urls {
            let trimmedUrl = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUrl.isEmpty else { continue }

            let item = DownloadItem(
                url: trimmedUrl,
                format: format,
                quality: quality,
                destinationFolder: downloadFolder,
                progress: 0,
                status: .pending,
                message: "Queued"
            )

            items.append(item)
            updateItem(item.id) { item in
                item.status = .downloading
                item.message = "Starting"
                item.progress = 0
            }

            do {
                try await download(itemID: item.id)
            } catch {
                updateItem(item.id) { item in
                    item.status = .failed
                    item.message = "Download failed"
                }
                await appendHistory(for: item.id)
            }
        }
    }

    private func download(itemID: UUID) async throws {
        guard let item = items.first(where: { $0.id == itemID }) else {
            throw DownloadError.itemNotFound
        }

        updateItem(itemID) { item in
            item.status = .downloading
            item.message = "Preparing download..."
            item.progress = 0
        }

        let (uploaderName, uploaderUsername) = await fetchUploaderInfo(for: item.url)
        updateItem(itemID) { item in
            item.accountName = uploaderName
            item.accountUsername = uploaderUsername ?? ""
        }

        if prefixDate {
            let seq = nextDailySequence()
            let prefix = dailySequencePrefix(sequence: seq)
            updateItem(itemID) { item in
                item.sequencePrefix = prefix
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = makeArguments(for: item)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let readTask = Task { [weak self] in
            await self?.readOutput(from: pipe.fileHandleForReading, itemID: itemID)
        }

        let exitCode = try await runProcess(process)

        await readTask.value
        pipe.fileHandleForReading.closeFile()

        if exitCode == 0 {
            updateItem(itemID) { item in
                item.status = .success
                item.progress = 1
                item.message = "Download completed"
            }
            if removeEmojis || prefixDate {
                await renameDownloadedFileIfNeeded(itemID: itemID)
            }
        } else {
            updateItem(itemID) { item in
                item.status = .failed
                item.message = "yt-dlp exited with code \(exitCode)"
                if item.errorMessage.isEmpty {
                    item.errorMessage = "Download failed with exit code \(exitCode)"
                }
            }
        }

        await appendHistory(for: itemID)
    }

    private func makeArguments(for item: DownloadItem) -> [String] {
        var arguments = [String]()
        arguments += ["--newline", "--no-playlist", "-o", "\(downloadFolder)/%(title)s.%(ext)s"]

        if item.format.isAudio {
            arguments += ["-x", "--audio-format", item.format.rawValue.lowercased(), "--audio-quality", item.quality.audioQualityOption()]
        } else {
            arguments += ["-f", "bestvideo[ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"]
            arguments += ["--merge-output-format", "mp4"]
            arguments += ["--ffmpeg-location", "/usr/local/bin/ffmpeg"]
        }

        arguments += ["--force-overwrites"]
        arguments.append(item.url)
        return arguments
    }

    private func parseProgress(from text: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)%"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let percentText = String(text[range]).replacingOccurrences(of: "%", with: "")
        return Double(percentText).map { min(max($0 / 100, 0), 1) }
    }

    private func renameDownloadedFileIfNeeded(itemID: UUID) async {
        guard let item = items.first(where: { $0.id == itemID }), let filePath = item.filePath else {
            return
        }

        let cleanedFilePath = cleanPath(filePath)
        let currentURL = URL(fileURLWithPath: cleanedFilePath)
        guard FileManager.default.fileExists(atPath: currentURL.path) else {
            return
        }

        let originalName = currentURL.deletingPathExtension().lastPathComponent
        var finalName = originalName

        if removeEmojis {
            finalName = stripEmojis(from: finalName).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if prefixDate {
            finalName = prefixDateString(to: finalName, prefix: item.sequencePrefix.isEmpty ? nil : item.sequencePrefix)
        }

        finalName = normalizeTitle(finalName)
        if finalName.isEmpty {
            finalName = "No Title"
        }

        let fileExtension = currentURL.pathExtension
        let newFilename = fileExtension.isEmpty ? finalName : "\(finalName).\(fileExtension)"
        let destinationURL = currentURL.deletingLastPathComponent().appendingPathComponent(newFilename)
        let finalDestinationURL = uniqueURL(for: destinationURL)

        guard finalDestinationURL.path != currentURL.path else {
            updateItem(itemID) { item in
                item.errorMessage = ""
            }
            return
        }

        do {
            try FileManager.default.moveItem(at: currentURL, to: finalDestinationURL)
            updateItem(itemID) { item in
                item.filePath = finalDestinationURL.path
                item.title = finalDestinationURL.deletingPathExtension().lastPathComponent
                item.errorMessage = ""
            }
        } catch {
            updateItem(itemID) { item in
                item.errorMessage = "Failed to rename downloaded file: \(error.localizedDescription)"
            }
        }
    }

    private func uniqueURL(for url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return url
        }

        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        for index in 1...999 {
            let suffix = String(format: "-%02d", index)
            let candidateName = baseName + suffix
            let candidateURL = directory.appendingPathComponent(fileExtension.isEmpty ? candidateName : "\(candidateName).\(fileExtension)")
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        return url
    }

    private func stripEmojis(from text: String) -> String {
        let filteredScalars = text.unicodeScalars.filter { scalar in
            !(scalar.properties.isEmojiPresentation || scalar.properties.isEmoji)
        }
        return String(String.UnicodeScalarView(filteredScalars))
    }

    private func cleanPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            return String(trimmed.dropFirst().dropLast())
        }
        if trimmed.hasPrefix("'") && trimmed.hasSuffix("'") {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private func updateTitle(from pathStr: String, itemID: UUID) {
        let cleaned = cleanPath(pathStr)
        let components = cleaned.split(separator: "/")
        if let lastComponent = components.last {
            let parts = String(lastComponent).split(separator: ".")
            let rawTitle = parts.first.map(String.init) ?? String(lastComponent)
            var title = rawTitle
            if removeEmojis {
                title = stripEmojis(from: title)
            }
            let seqPrefix = items.first(where: { $0.id == itemID })?.sequencePrefix
            if prefixDate {
                title = prefixDateString(to: title, prefix: seqPrefix)
            }
            let finalTitle = normalizeTitle(title)
            updateItem(itemID) { item in
                item.title = finalTitle.isEmpty ? "No Title" : finalTitle
            }
        }
    }

    private func normalizeTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func parseMessage(from text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prefixDateString(to title: String, prefix: String? = nil) -> String {
        let datePrefix: String
        if let prefix = prefix, !prefix.isEmpty {
            datePrefix = prefix
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            datePrefix = formatter.string(from: Date())
        }
        return "\(datePrefix) \(title)"
    }

    private func nextDailySequence() -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let key = "YTDLManager_DailyCounter_\(today)"
        let next = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(next, forKey: key)
        return next
    }

    private func dailySequencePrefix(sequence: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return String(format: "%@-%02d", today, sequence)
    }

    private func extractDownloadedPath(from line: String) -> String? {
        if line.contains("Merging formats into") {
            if let mergerRange = line.range(of: "Merging formats into") {
                return String(line[mergerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if line.contains("Destination:") {
            if let destinationRange = line.range(of: "Destination:") {
                return String(line[destinationRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func updateItem(_ id: UUID, updater: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        updater(&items[index])
    }

    private func appendHistory(for itemID: UUID) async {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        history.insert(item, at: 0)

        let historyEntry = DownloadHistoryEntry(
            id: UUID(),
            url: item.url,
            title: item.title.isEmpty ? item.url : item.title,
            accountName: item.accountName.isEmpty ? nil : item.accountName,
            accountUsername: item.accountUsername.isEmpty ? nil : item.accountUsername,
            platform: platform(for: item.url),
            downloadDate: Date(),
            format: item.format,
            quality: item.quality,
            filePath: item.filePath,
            status: item.status,
            errorMessage: item.errorMessage.isEmpty ? nil : item.errorMessage
        )

        persistentHistoryManager.add(historyEntry)
        persistentHistory = persistentHistoryManager.entries
    }

    func redownload(entry: DownloadHistoryEntry) {
        Task {
            await startDownloads(urls: [entry.url], format: entry.format, quality: entry.quality)
        }
    }

    func clearPersistentHistory() {
        persistentHistoryManager.clear()
        persistentHistory = persistentHistoryManager.entries
    }

    private func platform(for urlString: String) -> DownloadPlatform {
        let lowercased = urlString.lowercased()

        if lowercased.contains("youtube.com") || lowercased.contains("youtu.be") {
            return .youtube
        }
        if lowercased.contains("tiktok.com") {
            return .tiktok
        }
        if lowercased.contains("instagram.com") {
            return .instagram
        }
        if lowercased.contains("twitter.com") || lowercased.contains("x.com") {
            return .twitter
        }
        if lowercased.contains("reddit.com") {
            return .reddit
        }
        return .unknown
    }

    func cancelDownload(itemID: UUID) {
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items.remove(at: index)
        }
    }

    private func fetchUploaderInfo(for url: String) async -> (name: String, username: String?) {
        do {
            let output = try await runShellCommand(
                ytDlpPath,
                arguments: ["--no-download", "--print", "%(uploader)s", "--print", "%(uploader_id)s", url]
            )
            let lines = output.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            let rawName = lines.first ?? ""
            let name = (rawName.isEmpty || rawName == "NA" || rawName.lowercased() == "none")
                ? "Unknown" : rawName

            let rawId = lines.dropFirst().first ?? ""
            let username: String?
            if rawId.isEmpty || rawId == "NA" || rawId.lowercased() == "none" {
                username = nil
            } else if rawId.hasPrefix("UC") && rawId.count > 20 {
                // YouTube internal channel ID — not a readable handle
                username = nil
            } else if rawId.hasPrefix("@") {
                username = rawId
            } else {
                username = "@\(rawId)"
            }

            return (name, username)
        } catch {
            return ("Unknown", nil)
        }
    }

    private func runShellCommand(_ command: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    private func runProcess(_ process: Process) async throws -> Int32 {
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finishedProcess in
                continuation.resume(returning: finishedProcess.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func readOutput(from handle: FileHandle, itemID: UUID) async {
        do {
            let lines = handle.bytes.lines
            for try await line in lines {
                let text = parseMessage(from: line)
                if let pathStr = extractDownloadedPath(from: line) {
                    let cleanedPath = cleanPath(pathStr)
                    updateItem(itemID) { item in
                        item.filePath = cleanedPath
                    }
                    updateTitle(from: cleanedPath, itemID: itemID)
                } else if text.lowercased().contains("error:") || text.lowercased().contains("[error]") {
                    updateItem(itemID) { item in
                        item.errorMessage = text
                    }
                }
                if let progress = parseProgress(from: text) {
                    updateItem(itemID) { item in
                        item.progress = progress
                        item.message = text
                    }
                } else {
                    updateItem(itemID) { item in
                        item.message = text
                    }
                }
            }
        } catch {
            updateItem(itemID) { item in
                item.status = .failed
                item.message = "Failed to read yt-dlp output: \(error.localizedDescription)"
                item.errorMessage = error.localizedDescription
            }
        }
    }
}

extension DownloadManager {
    enum DownloadError: Error {
        case itemNotFound
    }
}
