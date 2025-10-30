import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Form {
            Section(header: Text("Manifest")) {
                HStack {
                    TextField("Manifest Path", text: Binding(
                        get: { viewModel.manifestURL?.path ?? "" },
                        set: { viewModel.manifestURL = $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
                    ))
                    Button("Choose…") { viewModel.selectManifestFile() }
                }
                if !viewModel.manifestChecksumPreview.isEmpty {
                    Label("Last checksum: \(viewModel.manifestChecksumPreview)", systemImage: "doc.append")
                        .font(.footnote)
                }
                if !viewModel.manifestPathPreview.isEmpty {
                    Label("Tracked path: \(viewModel.manifestPathPreview)", systemImage: "folder")
                        .font(.footnote)
                }
            }

            Section(header: Text("Git")) {
                HStack {
                    TextField("Repository Path", text: $viewModel.gitConfiguration.repositoryPath)
                    Button("Browse…") { viewModel.selectGitRepository() }
                }
                if !viewModel.gitConfiguration.repositoryPath.isEmpty {
                    Label(viewModel.gitConfiguration.repositoryPath, systemImage: "externaldrive")
                        .font(.footnote)
                }
                TextField("Remote", text: $viewModel.gitConfiguration.remote)
                TextField("Branch", text: $viewModel.gitConfiguration.branch)
                SecureField("Personal Access Token", text: $viewModel.gitConfiguration.personalAccessToken)
                Toggle("Push automatically", isOn: $viewModel.gitConfiguration.pushAutomatically)
                Button("Test Connection") { viewModel.testGitConnection() }
                    .buttonStyle(.bordered)
                if let gitError = viewModel.gitErrorMessage {
                    Text(gitError)
                        .foregroundColor(.red)
                }
                if !viewModel.gitStatusMessage.isEmpty {
                    Text(viewModel.gitStatusMessage)
                        .foregroundColor(.green)
                }
                if !viewModel.gitOutput.isEmpty {
                    GroupBox("Git Output") {
                        ScrollView {
                            VStack(alignment: .leading) {
                                ForEach(viewModel.gitOutput, id: \.self) { line in
                                    Text(line)
                                        .font(.footnote)
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Settings")
    }
}
