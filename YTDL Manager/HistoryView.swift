import SwiftUI

struct HistoryView: View {
    let history: [DownloadItem]

    var body: some View {
        GroupBox("History") {
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
                            Text(item.url)
                                .lineLimit(1)
                                .font(.headline)
                            Text(item.status.label)
                                .font(.subheadline)
                                .foregroundColor(item.status.tintColor)
                            Text(item.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
