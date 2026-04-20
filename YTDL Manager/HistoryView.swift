import SwiftUI
import AppKit

struct HistoryView: View {
    let history: [DownloadItem]
    let onOpenFolder: (String) -> Void
    let onRetry: (String) -> Void

    var body: some View {
        GroupBox("History (\(history.count))") {
            if history.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No downloads yet.")
                        .foregroundColor(.secondary)
                    Text("Completed downloads and errors will appear here.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                List(history) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.status.symbolName)
                            .foregroundColor(item.status.tintColor)
                            .font(.title3)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            if !item.title.isEmpty {
                                Text(item.title)
                                    .lineLimit(1)
                                    .font(.headline)
                            }
                            Text(item.url)
                                .lineLimit(1)
                                .font(.subheadline)
                            Text(item.status.label)
                                .font(.caption)
                                .foregroundColor(item.status.tintColor)
                            if !item.errorMessage.isEmpty {
                                Text(item.errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text(item.message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if item.status == .success {
                            Button(action: {
                                onOpenFolder(item.filePath)
                            }) {
                                Image(systemName: "folder")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .onHover { isHovering in
                                if isHovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        } else if item.status == .failed {
                            Button(action: {
                                onRetry(item.url)
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .onHover { isHovering in
                                if isHovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.inset)
                .frame(minWidth: 360)
            }
        }
    }
}
