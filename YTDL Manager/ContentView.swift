//
//  ContentView.swift
//  YTDL Manager
//
//  Created by Fatih Kuyucuoglu on 19.04.2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var manager = DownloadManager()
    @State private var urls: [String] = [""]
    @State private var selectedFormat: DownloadFormat = .mp4
    @State private var selectedQuality: DownloadQuality = .best
    @State private var showSettings = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            leftPanel
            HistoryView(history: manager.history)
                .frame(minWidth: 380)
        }
        .padding(20)
        .frame(minWidth: 1040, minHeight: 660)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showSettings = true }) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(downloadFolder: $manager.downloadFolder)
        }
        .alert("Download Issue", isPresented: $showAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(alertMessage)
        })
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("YTDL Manager")
                .font(.largeTitle)
                .bold()

            GroupBox("Download Settings") {
                VStack(alignment: .leading, spacing: 14) {
                    urlList

                    HStack {
                        Picker("Format", selection: $selectedFormat) {
                            ForEach(DownloadFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Quality", selection: $selectedQuality) {
                            ForEach(DownloadQuality.allCases) { quality in
                                Text(quality.rawValue).tag(quality)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Download folder")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(manager.downloadFolder)
                                .font(.footnote)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Button("Change Folder") {
                            showSettings = true
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: downloadAction) {
                        Label("Download", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(activeUrls.isEmpty || manager.ytDlpPath == nil)
                }
                .padding(12)
            }

            GroupBox("Active Downloads") {
                if manager.items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No downloads in progress.")
                            .foregroundColor(.secondary)
                        Text("Queued downloads will appear here with live progress.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(manager.items) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.url)
                                                .lineLimit(1)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Text(item.message)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Label(item.status.label, systemImage: item.status.symbolName)
                                            .labelStyle(.iconOnly)
                                            .foregroundColor(item.status.tintColor)
                                    }

                                    ProgressView(value: item.progress)
                                        .progressViewStyle(.linear)
                                        .frame(height: 10)
                                        .opacity(item.status == .success || item.status == .failed ? 0.7 : 1)
                                }
                                .padding(12)
                                .background(Color(NSColor.windowBackgroundColor))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 360)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minWidth: 620)
    }

    private var urlList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Video URLs")
                .font(.headline)

            ForEach(urls.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    TextField("Enter video URL", text: $urls[index])
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)

                    if urls.count > 1 {
                        Button(role: .destructive) {
                            urls.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                        .help("Remove URL")
                    }
                }
            }

            Button(action: addUrl) {
                Label("Add URL", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
        }
    }

    private var activeUrls: [String] {
        urls.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func addUrl() {
        urls.append("")
    }

    private func downloadAction() {
        guard !activeUrls.isEmpty else {
            alertMessage = "Please add at least one valid URL before starting the download."
            showAlert = true
            return
        }

        if manager.ytDlpPath == nil {
            alertMessage = "yt-dlp not found. Install yt-dlp or make sure it is available at /usr/local/bin/yt-dlp."
            showAlert = true
            return
        }

        Task {
            await manager.startDownloads(urls: activeUrls, format: selectedFormat, quality: selectedQuality)
        }
    }
}

#Preview {
    ContentView()
}
