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
            }

            Section(header: Text("Git")) {
                TextField("Repository Path", text: $viewModel.gitConfiguration.repositoryPath)
                TextField("Remote", text: $viewModel.gitConfiguration.remote)
                TextField("Branch", text: $viewModel.gitConfiguration.branch)
                SecureField("Personal Access Token", text: $viewModel.gitConfiguration.personalAccessToken)
                Toggle("Push automatically", isOn: $viewModel.gitConfiguration.pushAutomatically)
            }
        }
        .padding()
        .navigationTitle("Settings")
    }
}
