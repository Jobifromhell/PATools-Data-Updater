import SwiftUI

struct AmpLoadWorkspaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VStack(alignment: .leading) {
            metadataSection
            Divider()
            amplifierList
            Divider()
            publishSection
        }
        .padding()
        .navigationTitle("Amp Load")
        .toolbar {
            ToolbarItemGroup {
                Button("Open") { viewModel.selectAmpLoadFile() }
                Button("Save") { viewModel.saveAmpLoad() }
            }
        }
    }

    private var metadataSection: some View {
        GroupBox("Metadata") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Dataset Version")
                    Spacer()
                    TextField("Version", text: $viewModel.ampLoadDataset.version)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                HStack {
                    Text("Dataset Identifier")
                    Spacer()
                    TextField("Identifier", text: $viewModel.ampLoadDatasetId)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                if let path = viewModel.ampLoadFileURL?.path {
                    Label(path, systemImage: "doc.text")
                        .font(.footnote)
                }
                Toggle("Track manifest path", isOn: $viewModel.shouldUpdateManifestPath)
                Toggle("Bump manifest version", isOn: $viewModel.shouldBumpVersion)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var amplifierList: some View {
        GroupBox("Amplifiers") {
            VStack(alignment: .leading) {
                if viewModel.ampLoadDataset.amplifiers.isEmpty {
                    Text("Add amplifiers to begin.")
                        .foregroundColor(.secondary)
                }
                List {
                    ForEach($viewModel.ampLoadDataset.amplifiers) { $amplifier in
                        AmplifierEditor(amplifier: $amplifier) {
                            duplicate(amplifier: amplifier)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.ampLoadDataset.amplifiers.remove(atOffsets: offsets)
                    }
                }
                .frame(height: 300)
                HStack {
                    Button(action: addAmplifier) {
                        Label("Add Amplifier", systemImage: "plus")
                    }
                    if undoManager?.canUndo == true {
                        Button("Undo") { undoManager?.undo() }
                    }
                    if undoManager?.canRedo == true {
                        Button("Redo") { undoManager?.redo() }
                    }
                }
            }
        }
    }

    private var publishSection: some View {
        GroupBox("Publish") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Release Notes")
                    .font(.headline)
                TextEditor(text: $viewModel.publishNotes)
                    .frame(minHeight: 80)
                    .border(Color.gray.opacity(0.4))
                Button(action: { viewModel.publish(dataset: .ampLoad) }) {
                    Label("Publish Dataset", systemImage: "icloud.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .foregroundColor(.green)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
                if !viewModel.validationMessages.isEmpty {
                    ForEach(viewModel.validationMessages) { issue in
                        Text("• \(issue.message)")
                            .foregroundColor(.orange)
                    }
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
                if !viewModel.manifestChecksumPreview.isEmpty {
                    Label("Checksum: \(viewModel.manifestChecksumPreview)", systemImage: "checkmark.shield")
                        .font(.footnote)
                }
            }
        }
    }

    private func addAmplifier() {
        withAnimation {
            viewModel.ampLoadDataset.amplifiers.append(Amplifier())
        }
    }

    private func duplicate(amplifier: Amplifier) {
        withAnimation {
            var copy = amplifier
            copy.id = UUID()
            copy.name += " Copy"
            viewModel.ampLoadDataset.amplifiers.append(copy)
        }
    }
}

private struct AmplifierEditor: View {
    @Binding var amplifier: Amplifier
    var onDuplicate: () -> Void

    var body: some View {
        DisclosureGroup(amplifier.displayName.isEmpty ? "New Amplifier" : amplifier.displayName) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: $amplifier.name)
                TextField("Brand", text: $amplifier.brand)
                loadSection
            }
            .padding(.top, 8)
        }
        .contextMenu {
            Button("Duplicate", action: onDuplicate)
        }
    }

    private var loadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Loads")
                    .font(.headline)
                Spacer()
                Button(action: addLoad) {
                    Label("Add Load", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            ForEach($amplifier.loads) { $load in
                VStack(alignment: .leading) {
                    TextField("Model Name", text: $load.modelName)
                    HStack {
                        Stepper(value: $load.total, in: 0...10_000) {
                            Text("Total: \(load.total)")
                        }
                        Stepper(value: $load.perChannel, in: 0...10_000) {
                            Text("Per Channel: \(load.perChannel)")
                        }
                        Spacer()
                        Button(role: .destructive, action: { removeLoad(load) }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.05)))
            }
        }
    }

    private func addLoad() {
        amplifier.loads.append(SpeakerLoad())
    }

    private func removeLoad(_ load: SpeakerLoad) {
        amplifier.loads.removeAll { $0.id == load.id }
    }
}
