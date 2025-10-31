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

    @Published var ampLoadFileURL: URL? {
        didSet { persistURL(ampLoadFileURL, key: DefaultsKeys.ampLoadFileURL) }
    }
    @Published var prealignmentFileURL: URL? {
        didSet { persistURL(prealignmentFileURL, key: DefaultsKeys.prealignmentFileURL) }
    }
    @Published var manifestURL: URL? {
        didSet { persistURL(manifestURL, key: DefaultsKeys.manifestURL) }
    }
    @Published var releaseNotesURL: URL? {
        didSet {
            persistURL(releaseNotesURL, key: DefaultsKeys.releaseNotesURL)
            if !isRestoringState, releaseNotesURL != oldValue {
                reloadReleaseNotes()
            }
        }
    }

    @Published var ampLoadDatasetId: String = "ampload" {
        didSet { persistString(ampLoadDatasetId, key: DefaultsKeys.ampLoadDatasetId) }
    }
    @Published var prealignmentDatasetId: String = "prealignment" {
        didSet { persistString(prealignmentDatasetId, key: DefaultsKeys.prealignmentDatasetId) }
    }

    @Published var manifestChecksumPreview: String = ""
    @Published var manifestPathPreview: String = ""
    @Published var validationMessages: [ValidationIssue] = []
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""
    @Published var gitStatusMessage: String = ""
    @Published var gitErrorMessage: String?
    @Published var publishNotes: String = ""
    @Published var shouldBumpVersion: Bool = true {
        didSet { persistBool(shouldBumpVersion, key: DefaultsKeys.shouldBumpVersion) }
    }
    @Published var shouldUpdateManifestPath: Bool = true {
        didSet { persistBool(shouldUpdateManifestPath, key: DefaultsKeys.shouldUpdateManifestPath) }
    }
    @Published var gitConfiguration = GitConfiguration() {
        didSet {
            if !isUpdatingRepositoryPath,
               let bookmarkURL = gitRepositoryURL,
               bookmarkURL.path != gitConfiguration.repositoryPath {
                gitRepositoryURL = nil
            }
            persistGitConfiguration()
        }
    }
    @Published var gitRepositoryURL: URL? {
        didSet {
            guard gitRepositoryURL != oldValue else { return }
            persistURL(gitRepositoryURL, key: DefaultsKeys.gitRepositoryURL)
            if let path = gitRepositoryURL?.path {
                isUpdatingRepositoryPath = true
                gitConfiguration.repositoryPath = path
                isUpdatingRepositoryPath = false
            }
        }
    }
    @Published var gitOutput: [String] = []

    private let fileService: DatasetFileService
    private let manifestService: ManifestService
    private let releaseNotesService: ReleaseNotesService
    private let gitService: GitService
    private let defaults: UserDefaults

    private var suppressAmpDirtyFlag = false
    private var suppressPreDirtyFlag = false
    private var isRestoringState = false
    private var isUpdatingRepositoryPath = false

    @Published private(set) var ampLoadDirty = false
    @Published private(set) var prealignmentDirty = false

    init(fileService: DatasetFileService = DatasetFileService(),
         manifestService: ManifestService = ManifestService(),
         releaseNotesService: ReleaseNotesService = ReleaseNotesService(),
         gitService: GitService = GitService(),
         defaults: UserDefaults = .standard) {
        self.fileService = fileService
        self.manifestService = manifestService
        self.releaseNotesService = releaseNotesService
        self.gitService = gitService
        self.defaults = defaults
        self.ampLoadDataset = AmpLoadDataset.empty()
        self.prealignmentDataset = PrealignmentDataset.empty()
        restorePersistedState()
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
        }
    }

    func selectGitRepository() {
        presentOpenPanel(title: "Select Git Repository", canChooseDirectories: true, allowsFiles: false) { [weak self] url in
            self?.gitRepositoryURL = url
        }
    }

    func selectGitExecutable() {
        presentOpenPanel(title: "Select git Executable", canChooseDirectories: false, allowsFiles: true) { [weak self] url in
            self?.gitConfiguration.gitExecutablePath = url.path
        }
    }

    func saveAmpLoad() {
        guard let url = ampLoadFileURL else {
            errorMessage = "Select an ampload.json file first."
            return
        }
        do {
            try withSecurityScopedAccess(to: [url]) {
                try fileService.saveAmpLoad(ampLoadDataset, to: url)
            }
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
            try withSecurityScopedAccess(to: [url]) {
                try fileService.savePrealignment(prealignmentDataset, to: url)
            }
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
        gitStatusMessage = ""
        gitErrorMessage = nil
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
            try withSecurityScopedAccess(to: [datasetURL]) {
                switch dataset {
                case .ampLoad:
                    try fileService.saveAmpLoad(ampLoadDataset, to: datasetURL)
                    ampLoadDirty = false
                case .prealignment:
                    try fileService.savePrealignment(prealignmentDataset, to: datasetURL)
                    prealignmentDirty = false
                }
            }

            var manifestResult: ManifestUpdateResult?
            if let manifestURL {
                try withSecurityScopedAccess(to: [manifestURL, datasetURL]) {
                    manifestResult = try manifestService.updateManifest(
                        at: manifestURL,
                        datasetURL: datasetURL,
                        datasetId: datasetId,
                        version: shouldBumpVersion ? datasetVersion : nil,
                        updatePath: shouldUpdateManifestPath
                    )
                }
                manifestChecksumPreview = manifestResult?.checksum ?? ""
                if let path = manifestResult?.entry?.path, !path.isEmpty {
                    manifestPathPreview = path
                }
            }

            if let releaseNotesURL {
                try withSecurityScopedAccess(to: [releaseNotesURL]) {
                    try releaseNotesService.appendEntry(
                        datasetId: datasetId,
                        version: datasetVersion,
                        date: Date(),
                        notes: publishNotes,
                        to: releaseNotesURL
                    )
                }
                reloadReleaseNotes()
            }

            var gitMessages: [String] = []
            if !gitConfiguration.repositoryPath.isEmpty {
                var filesToCommit: [URL] = [datasetURL]
                if let manifestURL { filesToCommit.append(manifestURL) }
                if let releaseNotesURL { filesToCommit.append(releaseNotesURL) }
                var securityURLs = filesToCommit
                if let repoURL = gitRepositoryURL {
                    securityURLs.append(repoURL)
                }
                if let executableURL = gitExecutableURL() {
                    securityURLs.append(executableURL)
                }
                let message = "Publish \(datasetId) v\(datasetVersion)"
                try withSecurityScopedAccess(to: securityURLs) {
                    gitMessages = try gitService.commitAndPush(files: filesToCommit, message: message, configuration: gitConfiguration)
                }
                gitOutput = gitMessages
                if gitConfiguration.pushAutomatically {
                    gitStatusMessage = "Committed and pushed changes to \(gitConfiguration.remote)/\(gitConfiguration.branch)."
                } else {
                    gitStatusMessage = "Committed changes to local repository."
                }
            }

            statusMessage = "Published \(dataset.displayName) dataset"
            publishNotes = ""
        } catch {
            if error is GitServiceError {
                gitErrorMessage = error.localizedDescription
            }
            errorMessage = error.localizedDescription
        }
    }

    func reloadReleaseNotes() {
        guard let url = releaseNotesURL else { return }
        do {
            let entries = try withSecurityScopedAccess(to: [url]) {
                try releaseNotesService.loadEntries(from: url)
            }
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
            let dataset = try withSecurityScopedAccess(to: [url]) {
                try fileService.loadAmpLoad(from: url)
            }
            applyAmpLoadDataset(dataset, url: url)
            statusMessage = "Loaded ampload.json"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPrealignment(from url: URL) {
        do {
            let dataset = try withSecurityScopedAccess(to: [url]) {
                try fileService.loadPrealignment(from: url)
            }
            applyPrealignmentDataset(dataset, url: url)
            statusMessage = "Loaded prealignment.json"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentOpenPanel(title: String, allowedFileTypes: [String]? = nil, canChooseDirectories: Bool = false, allowsFiles: Bool = true, completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = allowsFiles
        panel.canChooseDirectories = canChooseDirectories
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

    private func restorePersistedState() {
        isRestoringState = true
        defer { isRestoringState = false }

        if let storedAmpURL = restoreURL(forKey: DefaultsKeys.ampLoadFileURL) {
            if FileManager.default.fileExists(atPath: storedAmpURL.path) {
                loadAmpLoad(from: storedAmpURL)
            } else {
                ampLoadFileURL = storedAmpURL
            }
        }

        if let storedPrealignmentURL = restoreURL(forKey: DefaultsKeys.prealignmentFileURL) {
            if FileManager.default.fileExists(atPath: storedPrealignmentURL.path) {
                loadPrealignment(from: storedPrealignmentURL)
            } else {
                prealignmentFileURL = storedPrealignmentURL
            }
        }

        manifestURL = restoreURL(forKey: DefaultsKeys.manifestURL)
        releaseNotesURL = restoreURL(forKey: DefaultsKeys.releaseNotesURL)
        if let releaseNotesURL, FileManager.default.fileExists(atPath: releaseNotesURL.path) {
            reloadReleaseNotes()
        }

        gitRepositoryURL = restoreURL(forKey: DefaultsKeys.gitRepositoryURL)

        if let ampId = defaults.string(forKey: DefaultsKeys.ampLoadDatasetId) {
            ampLoadDatasetId = ampId
        }
        if let preId = defaults.string(forKey: DefaultsKeys.prealignmentDatasetId) {
            prealignmentDatasetId = preId
        }
        if defaults.object(forKey: DefaultsKeys.shouldBumpVersion) != nil {
            shouldBumpVersion = defaults.bool(forKey: DefaultsKeys.shouldBumpVersion)
        }
        if defaults.object(forKey: DefaultsKeys.shouldUpdateManifestPath) != nil {
            shouldUpdateManifestPath = defaults.bool(forKey: DefaultsKeys.shouldUpdateManifestPath)
        }

        var repoPath = defaults.string(forKey: DefaultsKeys.gitRepositoryPath) ?? ""
        if let gitRepositoryURL { repoPath = gitRepositoryURL.path }
        let defaultGitConfiguration = GitConfiguration()
        let remote = defaults.string(forKey: DefaultsKeys.gitRemote) ?? defaultGitConfiguration.remote
        let branch = defaults.string(forKey: DefaultsKeys.gitBranch) ?? defaultGitConfiguration.branch
        let token = defaults.string(forKey: DefaultsKeys.gitToken) ?? ""
        let executablePath = defaults.string(forKey: DefaultsKeys.gitExecutablePath) ?? ""
        let pushAutomatically = defaults.object(forKey: DefaultsKeys.gitPushAutomatically) as? Bool ?? defaultGitConfiguration.pushAutomatically
        gitConfiguration = GitConfiguration(
            repositoryPath: repoPath,
            remote: remote,
            branch: branch,
            personalAccessToken: token,
            pushAutomatically: pushAutomatically,
            gitExecutablePath: executablePath
        )
    }

    private func persistURL(_ url: URL?, key: String) {
        guard !isRestoringState else { return }
        if let url {
            do {
                let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                defaults.set(data, forKey: key)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func persistString(_ value: String, key: String) {
        guard !isRestoringState else { return }
        defaults.set(value, forKey: key)
    }

    private func persistBool(_ value: Bool, key: String) {
        guard !isRestoringState else { return }
        defaults.set(value, forKey: key)
    }

    private func persistGitConfiguration() {
        guard !isRestoringState else { return }
        defaults.set(gitConfiguration.repositoryPath, forKey: DefaultsKeys.gitRepositoryPath)
        defaults.set(gitConfiguration.remote, forKey: DefaultsKeys.gitRemote)
        defaults.set(gitConfiguration.branch, forKey: DefaultsKeys.gitBranch)
        defaults.set(gitConfiguration.personalAccessToken, forKey: DefaultsKeys.gitToken)
        defaults.set(gitConfiguration.pushAutomatically, forKey: DefaultsKeys.gitPushAutomatically)
        defaults.set(gitConfiguration.gitExecutablePath, forKey: DefaultsKeys.gitExecutablePath)
    }

    private func restoreURL(forKey key: String) -> URL? {
        if let bookmarkData = defaults.data(forKey: key) {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale {
                    let renewedData = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                    defaults.set(renewedData, forKey: key)
                }
                return url
            } catch {
                defaults.removeObject(forKey: key)
                errorMessage = error.localizedDescription
                return nil
            }
        }

        if let url = defaults.url(forKey: key) {
            do {
                let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                defaults.removeObject(forKey: key)
                defaults.set(data, forKey: key)
            } catch {
                errorMessage = error.localizedDescription
            }
            return url
        }

        return nil
    }

    private func withSecurityScopedAccess<T>(to urls: [URL], perform work: () throws -> T) rethrows -> T {
        var accessed: [URL] = []
        var seen = Set<String>()
        for url in urls {
            let insertion = seen.insert(url.path)
            if insertion.inserted {
                if url.startAccessingSecurityScopedResource() {
                    accessed.append(url)
                }
            }
        }
        defer {
            for url in accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try work()
    }

    private func withSecurityScopedAccess<T>(to urls: [URL?], perform work: () throws -> T) rethrows -> T {
        try withSecurityScopedAccess(to: urls.compactMap { $0 }, perform: work)
    }

    private func gitExecutableURL() -> URL? {
        let trimmed = gitConfiguration.gitExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed)
    }

    func testGitConnection() {
        gitErrorMessage = nil
        gitStatusMessage = ""
        gitOutput.removeAll()

        guard !gitConfiguration.repositoryPath.isEmpty else {
            gitErrorMessage = "Set the repository path before testing."
            return
        }

        do {
            var securityURLs: [URL] = []
            if let repoURL = gitRepositoryURL { securityURLs.append(repoURL) }
            if let executableURL = gitExecutableURL() { securityURLs.append(executableURL) }
            let output: String = try withSecurityScopedAccess(to: securityURLs) {
                try gitService.testConnection(configuration: gitConfiguration)
            }
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedOutput.isEmpty {
                gitOutput = ["No remote refs returned."]
            } else {
                gitOutput = trimmedOutput.components(separatedBy: .newlines)
            }
            gitStatusMessage = "Successfully connected to \(gitConfiguration.remote)."
        } catch {
            gitErrorMessage = error.localizedDescription
        }
    }
}

private enum DefaultsKeys {
    static let ampLoadFileURL = "AmpLoadFileURL"
    static let prealignmentFileURL = "PrealignmentFileURL"
    static let manifestURL = "ManifestFileURL"
    static let releaseNotesURL = "ReleaseNotesFileURL"
    static let ampLoadDatasetId = "AmpLoadDatasetId"
    static let prealignmentDatasetId = "PrealignmentDatasetId"
    static let shouldBumpVersion = "ShouldBumpVersion"
    static let shouldUpdateManifestPath = "ShouldUpdateManifestPath"
    static let gitRepositoryPath = "GitRepositoryPath"
    static let gitRemote = "GitRemote"
    static let gitBranch = "GitBranch"
    static let gitToken = "GitToken"
    static let gitPushAutomatically = "GitPushAutomatically"
    static let gitRepositoryURL = "GitRepositoryURL"
    static let gitExecutablePath = "GitExecutablePath"
}
