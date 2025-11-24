import XCTest
@testable import PATools_Data_Updater

final class PATools_Data_UpdaterTests: XCTestCase {
    func testAmpLoadEncodingAndDecoding() throws {
        let dataset = AmpLoadDataset(version: "1.0", amplifiers: [
            Amplifier(name: "StageAmp", brand: "Pro Audio", loads: [
                SpeakerLoad(modelName: "LineArray", total: 8000, perChannel: 1000)
            ])
        ])
        let service = DatasetFileService()
        let url = temporaryURL(named: "ampload.json")
        try service.saveAmpLoad(dataset, to: url)
        let decoded = try service.loadAmpLoad(from: url)
        XCTAssertEqual(decoded, dataset)
    }

    func testPrealignmentEncodingAndDecoding() throws {
        let dataset = PrealignmentDataset(version: "2.1", combos: [
            PrealignmentCombo(id: "combo-1", speaker: "Array", subSummary: "Dual subs", presetLabel: "Arena", components: [
                ComboComponent(role: "Top", name: "Tower", presetLabel: "Arena", delay: 1.5, phase: "0")
            ])
        ])
        let service = DatasetFileService()
        let url = temporaryURL(named: "prealignment.json")
        try service.savePrealignment(dataset, to: url)
        let decoded = try service.loadPrealignment(from: url)
        XCTAssertEqual(decoded, dataset)
    }

    func testChecksumMatchesExpectedValue() throws {
        let url = temporaryURL(named: "checksum.json")
        let data = "{\"value\":42}".data(using: .utf8)!
        try data.write(to: url)
        let checksum = try ChecksumService().sha256Checksum(for: url)
        XCTAssertEqual(checksum, "8df93b66914318e403d315f0dce274235a491091696e4d3ef1d6400ed1d66c10")
    }

    func testManifestUpdateCreatesEntry() throws {
        let datasetURL = temporaryURL(named: "dataset.json")
        try "{}".data(using: .utf8)!.write(to: datasetURL)
        let manifestURL = temporaryURL(named: "manifest.json")
        let service = ManifestService(fileService: DatasetFileService(), checksumService: ChecksumService())
        let result = try service.updateManifest(at: manifestURL, datasetURL: datasetURL, datasetId: "ampload", version: "1.0", updatePath: true)
        XCTAssertEqual(result.manifest.datasets.count, 1)
        let entry = result.manifest.datasets["ampload"]
        XCTAssertEqual(entry?.version, "1.0")
        XCTAssertEqual(entry?.path, datasetURL.path)
        let persisted = try DatasetFileService().loadManifest(from: manifestURL)
        XCTAssertEqual(persisted, result.manifest)
        let savedString = String(data: try Data(contentsOf: manifestURL), encoding: .utf8)
        XCTAssertTrue(savedString?.contains("\"datasets\"") == true)
    }

    func testManifestDecodingSupportsDictionaryFormat() throws {
        let json = """
        {
          "ampload": {
            "path": "/tmp/ampload.json",
            "version": "2.0",
            "checksum": "abc123"
          }
        }
        """.data(using: .utf8)!
        let url = temporaryURL(named: "manifest.json")
        try json.write(to: url)
        let manifest = try DatasetFileService().loadManifest(from: url)
        XCTAssertEqual(manifest.datasets.count, 1)
        XCTAssertEqual(manifest.datasets["ampload"]?.version, "2.0")
    }

    func testMalformedManifestReportsPathAndDecodingMessage() throws {
        let url = temporaryURL(named: "manifest.json")
        try "{ invalid json ]".data(using: .utf8)!.write(to: url)

        XCTAssertThrowsError(try DatasetFileService().loadManifest(from: url)) { error in
            guard case let DatasetFileServiceError.manifestDecodingFailed(path, message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(path, url.path)
            XCTAssertTrue(message.contains("not valid JSON"))
            XCTAssertTrue(error.localizedDescription.contains(url.path))
        }
    }

    func testManifestDecodingErrorIncludesCodingPathContext() throws {
        let json = """
        {
          "datasets": {
            "ampload": {
              "path": "/tmp/ampload.json",
              "version": [],
              "checksum": "abc123"
            }
          }
        }
        """.data(using: .utf8)!
        let url = temporaryURL(named: "manifest.json")
        try json.write(to: url)

        XCTAssertThrowsError(try DatasetFileService().loadManifest(from: url)) { error in
            guard case let DatasetFileServiceError.manifestDecodingFailed(path, message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(path, url.path)
            XCTAssertTrue(message.contains("datasets.ampload.version"))
            XCTAssertTrue(message.contains("Type mismatch"))
        }
    }

    func testManifestDatasetsArrayReportsHelpfulTypeMismatchMessage() throws {
        let json = """
        {
          "datasets": []
        }
        """.data(using: .utf8)!
        let url = temporaryURL(named: "manifest.json")
        try json.write(to: url)

        XCTAssertThrowsError(try DatasetFileService().loadManifest(from: url)) { error in
            guard case let DatasetFileServiceError.manifestDecodingFailed(path, message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(path, url.path)
            XCTAssertTrue(message.contains("datasets"))
            XCTAssertTrue(message.contains("dictionary"))
            XCTAssertTrue(message.contains("array"))
        }
    }

    func testGitServiceRepositoryMissingShowsHelpfulError() {
        let service = GitService()
        let configuration = GitConfiguration(repositoryPath: "/tmp/does/not/exist", remote: "origin", branch: "main")
        XCTAssertThrowsError(try service.commitAndPush(files: [], message: "Test", configuration: configuration)) { error in
            guard case let GitServiceError.repositoryNotFound(path) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(path, "/tmp/does/not/exist")
        }
    }

    func testGitServiceTestConnectionSucceeds() throws {
        let service = GitService()
        let workspace = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let repoDirectory = workspace.appendingPathComponent("working")
        let remoteDirectory = workspace.appendingPathComponent("remote.git")
        try FileManager.default.createDirectory(at: repoDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: remoteDirectory, withIntermediateDirectories: true)
        try runGit(in: remoteDirectory, arguments: ["init", "--bare"])
        try runGit(in: repoDirectory, arguments: ["init"])
        try runGit(in: repoDirectory, arguments: ["config", "user.email", "tester@example.com"])
        try runGit(in: repoDirectory, arguments: ["config", "user.name", "Tester"])
        let readme = repoDirectory.appendingPathComponent("README.md")
        if let data = "Hello".data(using: .utf8) {
            try data.write(to: readme)
        } else {
            XCTFail("Failed to encode README contents")
        }
        try runGit(in: repoDirectory, arguments: ["add", "."])
        try runGit(in: repoDirectory, arguments: ["commit", "-m", "Initial commit"])
        try runGit(in: repoDirectory, arguments: ["branch", "-M", "main"])
        try runGit(in: repoDirectory, arguments: ["remote", "add", "origin", remoteDirectory.path])
        try runGit(in: repoDirectory, arguments: ["push", "-u", "origin", "main"])

        let configuration = GitConfiguration(repositoryPath: repoDirectory.path, remote: "origin", branch: "main")
        let output = try service.testConnection(configuration: configuration)
        XCTAssertTrue(output.contains("refs/heads/main"))
    }

    func testGitServiceMissingExecutableShowsHelpfulError() throws {
        let service = GitService()
        let workspace = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let repoDirectory = workspace.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: repoDirectory, withIntermediateDirectories: true)
        let missingPath = workspace.appendingPathComponent("missing/git").path
        let configuration = GitConfiguration(
            repositoryPath: repoDirectory.path,
            remote: "origin",
            branch: "main",
            gitExecutablePath: missingPath
        )
        XCTAssertThrowsError(try service.testConnection(configuration: configuration)) { error in
            guard case let GitServiceError.gitExecutableNotFound(path) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(path, missingPath)
        }
    }

    func testGitServiceReportsSandboxBlockedExecutable() throws {
        let service = GitService()
        let workspace = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let repoDirectory = workspace.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: repoDirectory, withIntermediateDirectories: true)
        let fakeGit = workspace.appendingPathComponent("fakegit.sh")
        let script = """
        #!/bin/sh
        echo "xcrun: error: cannot be used within an App Sandbox." 1>&2
        exit 1
        """
        try script.write(to: fakeGit, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeGit.path)
        let configuration = GitConfiguration(
            repositoryPath: repoDirectory.path,
            remote: "origin",
            branch: "main",
            gitExecutablePath: fakeGit.path
        )
        XCTAssertThrowsError(try service.testConnection(configuration: configuration)) { error in
            guard case let GitServiceError.gitExecutableBlockedBySandbox(output) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(output.contains("App Sandbox"))
        }
    }

    private func temporaryURL(named name: String) -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    private func temporaryDirectory() -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    private func runGit(in directory: URL, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw NSError(domain: "GitTest", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }
        return output
    }
}
