import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class DownloadManager: ObservableObject {
    @Published var downloadFolder: String

    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var history: [DownloadItem] = []
    @Published var ytDlpPath: String

    private static let downloadFolderKey = "YTDLManagerDownloadFolder"
    private static let ytDlpPathKey = "YTDLManagerYtDlpPath"

    init() {
        let defaultFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
        self.downloadFolder = UserDefaults.standard.string(forKey: Self.downloadFolderKey) ?? defaultFolder
        let defaultYtDlpPath = "/opt/homebrew/bin/yt-dlp"
        self.ytDlpPath = UserDefaults.standard.string(forKey: Self.ytDlpPathKey) ?? defaultYtDlpPath
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

        await readTask.value

        if exitCode == 0 {
            updateItem(itemID) { item in
                item.status = .success
                item.progress = 1
                item.message = "Download completed"
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

    func cancelDownload(itemID: UUID) {
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items.remove(at: index)
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
                if line.contains("Destination:") {
                    // Extract full file path and title from destination line
                    // Format: "Destination: /full/path/to/filename.ext"
                    if let destStart = line.range(of: "Destination:") {
                        let pathStr = String(line[destStart.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        updateItem(itemID) { item in
                            item.filePath = pathStr
                        }
                        let components = pathStr.split(separator: "/")
                        if let lastComponent = components.last {
                            let parts = String(lastComponent).split(separator: ".")
                            let title = parts.first.map(String.init) ?? String(lastComponent)
                            updateItem(itemID) { item in
                                item.title = title
                            }
                        }
                    }
                } else if line.contains("ERROR") || line.contains("error") {
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
