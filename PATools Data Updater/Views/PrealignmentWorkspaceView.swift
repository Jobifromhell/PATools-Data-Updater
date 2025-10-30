import SwiftUI

struct PrealignmentWorkspaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VStack(alignment: .leading) {
            metadataSection
            Divider()
            combosSection
            Divider()
            publishSection
        }
        .padding()
        .navigationTitle("Pre-alignment")
        .toolbar {
            ToolbarItemGroup {
                Button("Open") { viewModel.selectPrealignmentFile() }
                Button("Save") { viewModel.savePrealignment() }
            }
        }
    }

    private var metadataSection: some View {
        GroupBox("Metadata") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Dataset Version")
                    Spacer()
                    TextField("Version", text: $viewModel.prealignmentDataset.version)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                HStack {
                    Text("Dataset Identifier")
                    Spacer()
                    TextField("Identifier", text: $viewModel.prealignmentDatasetId)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                datasetFileRow
                if let path = viewModel.prealignmentFileURL?.path {
                    Label(path, systemImage: "doc.text")
                        .font(.footnote)
                }
                Toggle("Track manifest path", isOn: $viewModel.shouldUpdateManifestPath)
                Toggle("Bump manifest version", isOn: $viewModel.shouldBumpVersion)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var combosSection: some View {
        GroupBox("Combos") {
            VStack(alignment: .leading) {
                List {
                    ForEach($viewModel.prealignmentDataset.combos) { $combo in
                        ComboEditor(combo: $combo)
                    }
                    .onDelete { offsets in
                        viewModel.prealignmentDataset.combos.remove(atOffsets: offsets)
                    }
                }
                .frame(height: 300)
                HStack {
                    Button(action: addCombo) {
                        Label("Add Combo", systemImage: "plus")
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
                Button(action: { viewModel.publish(dataset: .prealignment) }) {
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
                if !viewModel.manifestPathPreview.isEmpty {
                    Label("Manifest path: \(viewModel.manifestPathPreview)", systemImage: "folder")
                        .font(.footnote)
                }
            }
        }
    }

    private func addCombo() {
        withAnimation {
            viewModel.prealignmentDataset.combos.append(PrealignmentCombo())
        }
    }

    private var datasetFileRow: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Dataset File")
                Text(viewModel.prealignmentFileURL?.lastPathComponent ?? "No file selected")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Browse…") { viewModel.selectPrealignmentFile() }
            Button("Reload") { viewModel.reloadPrealignmentFromDisk() }
                .disabled(viewModel.prealignmentFileURL == nil)
        }
    }
}

private struct ComboEditor: View {
    @Binding var combo: PrealignmentCombo

    var body: some View {
        DisclosureGroup(combo.id.isEmpty ? "New Combo" : combo.id) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("ID", text: $combo.id)
                TextField("Speaker", text: $combo.speaker)
                TextField("Sub Summary", text: $combo.subSummary)
                TextField("Preset Label", text: $combo.presetLabel)
                componentsSection
            }
            .padding(.top, 8)
        }
    }

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Components")
                    .font(.headline)
                Spacer()
                Button(action: addComponent) {
                    Label("Add Component", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            ForEach($combo.components) { $component in
                VStack(alignment: .leading) {
                    TextField("Role", text: $component.role)
                    TextField("Name", text: $component.name)
                    TextField("Preset Label", text: $component.presetLabel)
                    HStack {
                        Text("Delay (ms)")
                        TextField("Delay", value: $component.delay, formatter: NumberFormatter.decimalFormatter)
                            .frame(width: 80)
                        Spacer()
                        Button(role: .destructive, action: { removeComponent(component) }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    TextField("Phase", text: $component.phase)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.05)))
            }
        }
    }

    private func addComponent() {
        combo.components.append(ComboComponent())
    }

    private func removeComponent(_ component: ComboComponent) {
        combo.components.removeAll { $0.id == component.id }
    }
}

private extension NumberFormatter {
    static var decimalFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        return formatter
    }
}
