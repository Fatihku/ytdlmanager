import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Binding var isPresented: Bool
    @Binding var downloadFolder: String
    @Binding var ytDlpPath: String
    @State private var showFolderPicker = false
    @State private var selectionError: String?
    @State private var localDownloadFolder: String = ""
    @State private var localYtDlpPath: String = ""

    private func saveSettings() {
        UserDefaults.standard.set(localDownloadFolder, forKey: "YTDLManagerDownloadFolder")
        UserDefaults.standard.set(localYtDlpPath, forKey: "YTDLManagerYtDlpPath")
        downloadFolder = localDownloadFolder
        ytDlpPath = localYtDlpPath
        isPresented = false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Download Settings")
                .font(.title2)
                .bold()

            Text("Current download folder:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(localDownloadFolder)
                .font(.body)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)

            Button(action: {
                showFolderPicker = true
            }) {
                Label("Choose Folder", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        localDownloadFolder = url.path
                    }
                case .failure(let error):
                    selectionError = error.localizedDescription
                }
            }

            if let selectionError {
                Text(selectionError)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            Text("yt-dlp executable path:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("Path to yt-dlp", text: $localYtDlpPath)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)

            Text("To find your yt-dlp path, open Terminal and type: which yt-dlp")
                .font(.footnote)
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("About YTDL Manager")
                    .font(.headline)

                Text("This app is a graphical user interface for the open-source yt-dlp project. yt-dlp must be installed on your system for this app to work.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: {
                    if let url = URL(string: "https://github.com/yt-dlp/yt-dlp") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("yt-dlp on GitHub")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let url = URL(string: "https://github.com/Fatihku/ytdlmanager") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("YTDL Manager on GitHub")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let url = URL(string: "https://github.com/Fatihku/ytdlmanager") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("YTDL Manager on GitHub")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)

                Text("To install yt-dlp, open Terminal and run: brew install yt-dlp")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 220)
        .onAppear {
            localDownloadFolder = downloadFolder
            localYtDlpPath = ytDlpPath
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSettings()
                }
            }
        }
    }
}
