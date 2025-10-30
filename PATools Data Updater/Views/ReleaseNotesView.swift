import SwiftUI

struct ReleaseNotesView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedDataset: DatasetKind? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Dataset", selection: $selectedDataset) {
                    Text("All").tag(DatasetKind?.none)
                    ForEach(DatasetKind.allCases) { dataset in
                        Text(dataset.displayName).tag(DatasetKind?.some(dataset))
                    }
                }
                .pickerStyle(.segmented)
                Spacer()
                Button("Select Release Notes") { viewModel.selectReleaseNotesFile() }
                if let path = viewModel.releaseNotesURL?.path {
                    Text(path)
                        .font(.footnote)
                }
            }
            List(filteredEntries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.datasetId) v\(entry.version)")
                        .font(.headline)
                    Text(entry.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if !entry.notes.isEmpty {
                        Text(entry.notes)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .navigationTitle("Release Notes")
    }

    private var filteredEntries: [ReleaseNoteEntry] {
        if let dataset = selectedDataset {
            return viewModel.releaseNoteEntries.filter { $0.datasetId == dataset.rawValue }
        }
        return viewModel.releaseNoteEntries
    }
}
