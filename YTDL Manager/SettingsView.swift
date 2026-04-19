import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Binding var downloadFolder: String
    @State private var showFolderPicker = false
    @State private var selectionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Download Settings")
                .font(.title2)
                .bold()

            Text("Current download folder:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(downloadFolder)
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
                        downloadFolder = url.path
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

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 220)
    }
}
