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

    private func temporaryURL(named name: String) -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }
}
