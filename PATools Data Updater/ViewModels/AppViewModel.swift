import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var ampLoadDataset: AmpLoadDataset {
        didSet { if !suppressAmpDirtyFlag { ampLoadDirty = true } }
    }
    @Published var prealignmentDataset: PrealignmentDataset {
        didSet { if !suppressPreDirtyFlag { prealignmentDirty = true } }
    }

    @Published var ampLoadFileURL: URL?
    @Published var prealignmentFileURL: URL?
    @Published var manifestURL: URL?
    @Published var releaseNotesURL: URL?

    @Published var ampLoadDatasetId: String = "ampload"
    @Published var prealignmentDatasetId: String = "prealignment"

    @Published var manifestChecksumPreview: String = ""
    @Published var manifestPathPreview: String = ""
    @Published var validationMessages: [ValidationIssue] = []
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""
    @Published var publishNotes: String = ""
    @Published var shouldBumpVersion: Bool = true
    @Published var shouldUpdateManifestPath: Bool = true
    @Published var gitConfiguration = GitConfiguration()
    @Published var gitOutput: [String] = []

    private let fileService: DatasetFileService
    private let manifestService: ManifestService
    private let releaseNotesService: ReleaseNotesService
    private let gitService: GitService

    private var suppressAmpDirtyFlag = false
    private var suppressPreDirtyFlag = false

    @Published private(set) var ampLoadDirty = false
    @Published private(set) var prealignmentDirty = false

    init(fileService: DatasetFileService = DatasetFileService(),
         manifestService: ManifestService = ManifestService(),
         releaseNotesService: ReleaseNotesService = ReleaseNotesService(),
         gitService: GitService = GitService()) {
        self.fileService = fileService
        self.manifestService = manifestService
        self.releaseNotesService = releaseNotesService
        self.gitService = gitService
        self.ampLoadDataset = AmpLoadDataset.empty()
        self.prealignmentDataset = PrealignmentDataset.empty()
    }

    var hasUnsavedChanges: Bool {
        ampLoadDirty || prealignmentDirty
    }

    func presentUnsavedChangesAlert() {
        let alert = NSAlert()
        alert.messageText = "You have unsaved dataset changes."
        alert.informativeText = "Save your work before quitting to avoid losing changes."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func selectAmpLoadFile() {
        presentOpenPanel(title: "Select ampload.json", allowedFileTypes: ["json"]) { [weak self] url in
            self?.loadAmpLoad(from: url)
        }
    }

    func loadAmpLoad(fromPath path: String) {
        guard !path.isEmpty else { return }
        loadAmpLoad(from: URL(fileURLWithPath: path))
    }

    func reloadAmpLoadFromDisk() {
        guard let url = ampLoadFileURL else {
            errorMessage = "Select an ampload.json file first."
            return
        }
        loadAmpLoad(from: url)
    }

    func selectPrealignmentFile() {
        presentOpenPanel(title: "Select prealignment.json", allowedFileTypes: ["json"]) { [weak self] url in
            self?.loadPrealignment(from: url)
        }
    }

    func loadPrealignment(fromPath path: String) {
        guard !path.isEmpty else { return }
        loadPrealignment(from: URL(fileURLWithPath: path))
    }

    func reloadPrealignmentFromDisk() {
        guard let url = prealignmentFileURL else {
            errorMessage = "Select a prealignment.json file first."
            return
        }
        loadPrealignment(from: url)
    }

    func selectManifestFile() {
        presentOpenPanel(title: "Select manifest.json", allowedFileTypes: ["json"]) { [weak self] url in
            self?.manifestURL = url
        }
    }

    func selectReleaseNotesFile() {
        presentSavePanel(title: "Select ReleaseNotes.md", nameField: "ReleaseNotes.md") { [weak self] url in
            guard let self else { return }
            self.releaseNotesURL = url
            self.reloadReleaseNotes()
        }
    }

    func saveAmpLoad() {
        guard let url = ampLoadFileURL else {
            errorMessage = "Select an ampload.json file first."
            return
        }
        do {
            try fileService.saveAmpLoad(ampLoadDataset, to: url)
            ampLoadDirty = false
            statusMessage = "Saved ampload.json"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePrealignment() {
        guard let url = prealignmentFileURL else {
            errorMessage = "Select a prealignment.json file first."
            return
        }
        do {
            try fileService.savePrealignment(prealignmentDataset, to: url)
            prealignmentDirty = false
            statusMessage = "Saved prealignment.json"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func publish(dataset: DatasetKind) {
        validationMessages = []
        errorMessage = nil
        statusMessage = ""
        gitOutput.removeAll()

        let datasetURL: URL?
        let datasetVersion: String
        let datasetId: String
        let validation: [ValidationIssue]

        switch dataset {
        case .ampLoad:
            datasetURL = ampLoadFileURL
            datasetVersion = ampLoadDataset.version
            datasetId = ampLoadDatasetId
            validation = ampLoadDataset.validate()
        case .prealignment:
            datasetURL = prealignmentFileURL
            datasetVersion = prealignmentDataset.version
            datasetId = prealignmentDatasetId
            validation = prealignmentDataset.validate()
        }

        guard validation.isEmpty else {
            validationMessages = validation
            return
        }

        guard let datasetURL = datasetURL else {
            errorMessage = "Select a dataset file before publishing."
            return
        }

        do {
            switch dataset {
            case .ampLoad:
                try fileService.saveAmpLoad(ampLoadDataset, to: datasetURL)
                ampLoadDirty = false
            case .prealignment:
                try fileService.savePrealignment(prealignmentDataset, to: datasetURL)
                prealignmentDirty = false
            }

            var manifestResult: ManifestUpdateResult?
            if let manifestURL {
                manifestResult = try manifestService.updateManifest(at: manifestURL, datasetURL: datasetURL, datasetId: datasetId, version: shouldBumpVersion ? datasetVersion : nil, updatePath: shouldUpdateManifestPath)
                manifestChecksumPreview = manifestResult?.checksum ?? ""
                if let path = manifestResult?.entry?.path, !path.isEmpty {
                    manifestPathPreview = path
                }
            }

            if let releaseNotesURL {
                try releaseNotesService.appendEntry(datasetId: datasetId, version: datasetVersion, date: Date(), notes: publishNotes, to: releaseNotesURL)
                reloadReleaseNotes()
            }

            var gitMessages: [String] = []
            if !gitConfiguration.repositoryPath.isEmpty {
                var filesToCommit: [URL] = [datasetURL]
                if let manifestURL { filesToCommit.append(manifestURL) }
                if let releaseNotesURL { filesToCommit.append(releaseNotesURL) }
                let message = "Publish \(datasetId) v\(datasetVersion)"
                gitMessages = try gitService.commitAndPush(files: filesToCommit, message: message, configuration: gitConfiguration)
                gitOutput = gitMessages
            }

            statusMessage = "Published \(dataset.displayName) dataset"
            publishNotes = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadReleaseNotes() {
        guard let url = releaseNotesURL else { return }
        do {
            let entries = try releaseNotesService.loadEntries(from: url)
            releaseNoteEntries = entries
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @Published private(set) var releaseNoteEntries: [ReleaseNoteEntry] = []

    private func applyAmpLoadDataset(_ dataset: AmpLoadDataset, url: URL) {
        suppressAmpDirtyFlag = true
        ampLoadDataset = dataset
        suppressAmpDirtyFlag = false
        ampLoadFileURL = url
        ampLoadDirty = false
    }

    private func applyPrealignmentDataset(_ dataset: PrealignmentDataset, url: URL) {
        suppressPreDirtyFlag = true
        prealignmentDataset = dataset
        suppressPreDirtyFlag = false
        prealignmentFileURL = url
        prealignmentDirty = false
    }

    private func loadAmpLoad(from url: URL) {
        do {
            let dataset = try fileService.loadAmpLoad(from: url)
            applyAmpLoadDataset(dataset, url: url)
            statusMessage = "Loaded ampload.json"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPrealignment(from url: URL) {
        do {
            let dataset = try fileService.loadPrealignment(from: url)
            applyPrealignmentDataset(dataset, url: url)
            statusMessage = "Loaded prealignment.json"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentOpenPanel(title: String, allowedFileTypes: [String]? = nil, completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = title
        panel.allowedFileTypes = allowedFileTypes
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            completion(url)
        }
    }

    private func presentSavePanel(title: String, nameField: String, completion: @escaping (URL) -> Void) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = title
        panel.nameFieldStringValue = nameField
        panel.allowedFileTypes = ["md"]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            completion(url)
        }
    }
}
