import SwiftUI

enum WorkspaceSelection: Hashable {
    case ampLoad
    case prealignment
    case releaseNotes
    case settings
}

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selection: WorkspaceSelection? = .ampLoad

    var body: some View {
        NavigationSplitView(sidebar: {
            List(selection: $selection) {
                Section("Datasets") {
                    NavigationLink(value: WorkspaceSelection.ampLoad) {
                        Label("Amp Load", systemImage: "music.quarternote.3")
                    }
                    NavigationLink(value: WorkspaceSelection.prealignment) {
                        Label("Pre-alignment", systemImage: "waveform")
                    }
                }
                Section("Changelog") {
                    NavigationLink(value: WorkspaceSelection.releaseNotes) {
                        Label("Release Notes", systemImage: "doc.text")
                    }
                }
                Section("Configuration") {
                    NavigationLink(value: WorkspaceSelection.settings) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("PA Tools")
        }, detail: {
            switch selection {
            case .ampLoad:
                AmpLoadWorkspaceView(viewModel: viewModel)
            case .prealignment:
                PrealignmentWorkspaceView(viewModel: viewModel)
            case .releaseNotes:
                ReleaseNotesView(viewModel: viewModel)
            case .settings:
                SettingsView(viewModel: viewModel)
            case .none:
                Text("Select an item from the sidebar")
                    .foregroundColor(.secondary)
            }
        })
    }
}

#Preview {
    ContentView().environmentObject(AppViewModel())
}
