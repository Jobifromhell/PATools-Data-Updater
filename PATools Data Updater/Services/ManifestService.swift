import Foundation

final class ManifestService {
    private let fileService: DatasetFileService
    private let checksumService: ChecksumService

    init(fileService: DatasetFileService = DatasetFileService(), checksumService: ChecksumService = ChecksumService()) {
        self.fileService = fileService
        self.checksumService = checksumService
    }

    func updateManifest(at manifestURL: URL, datasetURL: URL, datasetId: String, version: String?, updatePath: Bool) throws -> ManifestUpdateResult {
        var manifest: Manifest
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            manifest = try fileService.loadManifest(from: manifestURL)
        } else {
            manifest = Manifest()
        }
        let checksum = try checksumService.sha256Checksum(for: datasetURL)
        let newPath = updatePath ? datasetURL.path : nil
        manifest.updateEntry(for: datasetId, checksum: checksum, version: version, path: newPath)
        try fileService.saveManifest(manifest, to: manifestURL)
        return ManifestUpdateResult(manifest: manifest, checksum: checksum)
    }
}

struct ManifestUpdateResult {
    let manifest: Manifest
    let checksum: String
}
