import SwiftUI

private let historyDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "dd.MM.yyyy"
    return f
}()

private struct CopyButton: View {
    let text: String
    @State private var copied = false
    @State private var isHovered = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.caption2)
                .foregroundColor(copied ? .green : isHovered ? .primary : .secondary)
                .padding(4)
                .background(isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.borderless)
        .help(copied ? "Copied!" : "Copy")
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

private struct PlatformBadge: View {
    let platform: DownloadPlatform

    var body: some View {
        Text(platform.badgeLabel)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(platform.badgeColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}

struct PersistentHistoryTabView: View {
    @ObservedObject var manager: DownloadManager
    var onAddToList: ((String) -> Void)? = nil
    @State private var searchText = ""
    @State private var selectedPlatform: DownloadPlatform? = nil
    @State private var filterByDate = false
    @State private var selectedDate = Date()

    private var filteredHistory: [DownloadHistoryEntry] {
        manager.persistentHistory.filter { entry in
            let matchesSearch = searchText.isEmpty || entry.title.localizedCaseInsensitiveContains(searchText) || entry.url.localizedCaseInsensitiveContains(searchText)
            let matchesPlatform = selectedPlatform == nil || entry.platform == selectedPlatform
            let matchesDate = !filterByDate || Calendar.current.isDate(entry.downloadDate, inSameDayAs: selectedDate)
            return matchesSearch && matchesPlatform && matchesDate
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                TextField("Search by title or URL", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 260)

                Picker("Platform", selection: $selectedPlatform) {
                    Text("All").tag(nil as DownloadPlatform?)
                    ForEach(DownloadPlatform.allCases) { platform in
                        Text(platform.rawValue).tag(platform as DownloadPlatform?)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 140)

                Toggle("Date", isOn: $filterByDate)
                    .toggleStyle(.switch)

                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!filterByDate)
                    .frame(maxWidth: 180)

                Spacer()

                Button(role: .destructive, action: manager.clearPersistentHistory) {
                    Label("Clear History", systemImage: "trash")
                }
                .help("Remove all persisted history entries")
            }
            .padding([.horizontal, .top], 20)

            if filteredHistory.isEmpty {
                VStack(alignment: .center, spacing: 10) {
                    Text("No history entries match your filters.")
                        .font(.headline)
                    Text("Run downloads in the Download tab to populate persistent history.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredHistory) { entry in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 12) {
                                    PlatformBadge(platform: entry.platform)
                                        .frame(width: 30, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(entry.title)
                                                .font(.headline)
                                                .lineLimit(1)
                                            CopyButton(text: entry.title)
                                        }

                                        HStack(spacing: 6) {
                                            let channelDisplay: String = {
                                                let name = entry.accountName ?? "Unknown"
                                                if let handle = entry.accountUsername {
                                                    return "\(name) • \(handle)"
                                                }
                                                return name
                                            }()
                                            Text(channelDisplay)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                            CopyButton(text: channelDisplay)
                                        }

                                        HStack(spacing: 6) {
                                            Text(entry.url)
                                                .font(.caption)
                                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                                                .lineLimit(1)
                                            CopyButton(text: entry.url)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(entry.status.label)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                            .background(entry.status.tintColor.opacity(0.2))
                                            .foregroundColor(entry.status.tintColor)
                                            .cornerRadius(8)

                                        Text(historyDateFormatter.string(from: entry.downloadDate))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                HStack(spacing: 16) {
                                    Text(entry.format.rawValue)
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(6)
                                    Text(entry.quality.rawValue)
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(6)
                                    if let filePath = entry.filePath {
                                        Text(filePath)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button {
                                        onAddToList?(entry.url)
                                    } label: {
                                        Label("Add to List", systemImage: "plus.circle")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .help("Add URL to download list")
                                    .onHover { hovering in
                                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                    }

                                    Button {
                                        manager.redownload(entry: entry)
                                    } label: {
                                        Label("Redownload", systemImage: "arrow.clockwise")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .help("Redownload with same format and quality")
                                    .onHover { hovering in
                                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(minWidth: 1040, minHeight: 660)
    }
}
