import Foundation
import Combine
import SwiftUI

enum DownloadPlatform: String, Codable, CaseIterable, Identifiable {
    case youtube = "YouTube"
    case tiktok = "TikTok"
    case instagram = "Instagram"
    case twitter = "Twitter/X"
    case reddit = "Reddit"
    case unknown = "Unknown"

    var id: Self { self }

    var iconName: String {
        switch self {
        case .youtube: return "play.rectangle"
        case .tiktok: return "music.note"
        case .instagram: return "camera"
        case .twitter: return "bird"
        case .reddit: return "r.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    var badgeLabel: String {
        switch self {
        case .youtube: return "YT"
        case .tiktok: return "TK"
        case .instagram: return "IG"
        case .twitter: return "TW"
        case .reddit: return "RD"
        case .unknown: return "?"
        }
    }

    var badgeColor: Color {
        switch self {
        case .youtube: return .red
        case .tiktok: return Color(red: 0.05, green: 0.05, blue: 0.05)
        case .instagram: return Color(red: 0.56, green: 0.13, blue: 0.73)
        case .twitter: return Color(red: 0.11, green: 0.63, blue: 0.95)
        case .reddit: return Color(red: 1.0, green: 0.27, blue: 0.0)
        case .unknown: return .gray
        }
    }
}

struct DownloadHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let url: String
    let title: String
    let accountName: String?
    let platform: DownloadPlatform
    let downloadDate: Date
    let format: DownloadFormat
    let quality: DownloadQuality
    let filePath: String?
    let status: DownloadStatus
    let errorMessage: String?
}

@MainActor
final class PersistentHistoryManager: ObservableObject {
    @Published private(set) var entries: [DownloadHistoryEntry] = []

    private static let directoryName = "YTDLManager"
    private static let fileName = "history.json"

    private var storageUrl: URL {
        let fileManager = FileManager.default
        if let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return applicationSupportURL
                .appendingPathComponent(Self.directoryName, isDirectory: true)
                .appendingPathComponent(Self.fileName)
        }
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent(Self.directoryName)
            .appendingPathComponent(Self.fileName)
    }

    init() {
        loadHistory()
    }

    func add(_ entry: DownloadHistoryEntry) {
        entries.insert(entry, at: 0)
        saveHistory()
    }

    func clear() {
        entries = []
        saveHistory()
    }

    private func loadHistory() {
        let url = storageUrl
        let directoryUrl = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true)
            guard FileManager.default.fileExists(atPath: url.path) else {
                entries = []
                return
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([DownloadHistoryEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    private func saveHistory() {
        let url = storageUrl
        let directoryUrl = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Silent failure; history will be reloaded next launch.
        }
    }
}
