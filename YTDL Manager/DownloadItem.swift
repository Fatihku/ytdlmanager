import Foundation
import SwiftUI

enum DownloadStatus: String, Codable {
    case pending
    case downloading
    case success
    case failed

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .downloading: return "Downloading"
        case .success: return "Completed"
        case .failed: return "Failed"
        }
    }

    var symbolName: String {
        switch self {
        case .pending: return "clock"
        case .downloading: return "arrow.down.circle"
        case .success: return "checkmark.circle"
        case .failed: return "xmark.octagon"
        }
    }

    var tintColor: Color {
        switch self {
        case .pending: return .gray
        case .downloading: return .blue
        case .success: return .green
        case .failed: return .red
        }
    }
}

enum DownloadFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4"
    case mkv = "MKV"
    case mp3 = "MP3"
    case aac = "AAC"

    var id: Self { self }
    var isAudio: Bool {
        switch self {
        case .mp3, .aac: return true
        default: return false
        }
    }
}

enum DownloadQuality: String, CaseIterable, Identifiable {
    case best = "Best"
    case p1080 = "1080p"
    case p720 = "720p"
    case p480 = "480p"

    var id: Self { self }

    func videoFilter() -> String {
        switch self {
        case .best:
            return "bestvideo+bestaudio/best"
        case .p1080:
            return "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"
        case .p720:
            return "bestvideo[height<=720]+bestaudio/best[height<=720]/best"
        case .p480:
            return "bestvideo[height<=480]+bestaudio/best[height<=480]/best"
        }
    }

    func audioQualityOption() -> String {
        switch self {
        case .best:
            return "0"
        case .p1080:
            return "5"
        case .p720:
            return "7"
        case .p480:
            return "9"
        }
    }
}

struct DownloadItem: Identifiable, Equatable {
    let id: UUID = UUID()
    let url: String
    let format: DownloadFormat
    let quality: DownloadQuality
    var destinationFolder: String
    var progress: Double = 0
    var status: DownloadStatus = .pending
    var message: String = "Waiting"
    var title: String = ""
    var errorMessage: String = ""
    var filePath: String?

    var formattedUrl: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
