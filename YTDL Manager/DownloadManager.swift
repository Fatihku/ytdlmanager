import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class DownloadManager: ObservableObject {
    @Published var downloadFolder: String {
        didSet {
            UserDefaults.standard.set(downloadFolder, forKey: Self.downloadFolderKey)
        }
    }

    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var history: [DownloadItem] = []
    @Published private(set) var ytDlpPath: String?
    @Published private(set) var lastError: String?

    private static let downloadFolderKey = "YTDLManagerDownloadFolder"

    init() {
        let defaultFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads").path
        self.downloadFolder = UserDefaults.standard.string(forKey: Self.downloadFolderKey) ?? defaultFolder
        Task { await self.locateYtDlp() }
    }

    func locateYtDlp() async {
        if FileManager.default.isExecutableFile(atPath: "/usr/local/bin/yt-dlp") {
            ytDlpPath = "/usr/local/bin/yt-dlp"
            return
        }

        do {
            let output = try await runShellCommand("/usr/bin/which", arguments: ["yt-dlp"])
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            ytDlpPath = path.isEmpty ? nil : path
        } catch {
            ytDlpPath = nil
        }
    }

    func startDownloads(urls: [String], format: DownloadFormat, quality: DownloadQuality) async {
        guard !urls.isEmpty else { return }
        guard ytDlpPath != nil else {
            lastError = "yt-dlp could not be found. Install it or place it under /usr/local/bin/yt-dlp."
            return
        }

        for rawUrl in urls {
            let trimmedUrl = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUrl.isEmpty else { continue }

            var item = DownloadItem(
                url: trimmedUrl,
                format: format,
                quality: quality,
                destinationFolder: downloadFolder,
                progress: 0,
                status: .pending,
                message: "Queued"
            )

            items.append(item)
            await updateItem(item.id) { item in
                item.status = .downloading
                item.message = "Starting"
                item.progress = 0
            }

            do {
                try await download(itemID: item.id)
            } catch {
                await updateItem(item.id) { item in
                    item.status = .failed
                    item.message = "Download failed"
                }
                await appendHistory(for: item.id)
            }
        }
    }

    private func download(itemID: UUID) async throws {
        guard let ytDlpPath else {
            throw DownloadError.missingYtDlp
        }
        guard let item = items.first(where: { $0.id == itemID }) else {
            throw DownloadError.itemNotFound
        }

        updateItem(itemID) { item in
            item.status = .downloading
            item.message = "Preparing download..."
            item.progress = 0
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
        pipe.fileHandleForReading.closeFile()

        try? await readTask.value

        if exitCode == 0 {
            await updateItem(itemID) { item in
                item.status = .success
                item.progress = 1
                item.message = "Download completed"
            }
        } else {
            await updateItem(itemID) { item in
                item.status = .failed
                item.message = "yt-dlp exited with code \(exitCode)"
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
            arguments += ["-f", item.quality.videoFilter()]
            if item.format == .mp4 {
                arguments += ["--merge-output-format", "mp4"]
            } else if item.format == .mkv {
                arguments += ["--recode-video", "mkv"]
            }
        }

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

    private func parseMessage(from text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateItem(_ id: UUID, updater: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        updater(&items[index])
    }

    private func appendHistory(for itemID: UUID) async {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        history.insert(item, at: 0)
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
        for try await lineData in handle.bytes.lines {
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            let text = parseMessage(from: line)
            if let progress = parseProgress(from: text) {
                await updateItem(itemID) { item in
                    item.progress = progress
                    item.message = text
                }
            } else {
                await updateItem(itemID) { item in
                    item.message = text
                }
            }
        }
    }
}

extension DownloadManager {
    enum DownloadError: Error {
        case missingYtDlp
        case itemNotFound
    }
}
