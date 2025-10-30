import Foundation

struct Manifest: Codable, Equatable {
    var datasets: [ManifestEntry]

    init(datasets: [ManifestEntry] = []) {
        self.datasets = datasets
    }

    mutating func updateEntry(for datasetId: String, checksum: String, version: String?, path: String?) {
        if let index = datasets.firstIndex(where: { $0.id == datasetId }) {
            datasets[index].checksum = checksum
            if let version = version {
                datasets[index].version = version
            }
            if let path = path {
                datasets[index].path = path
            }
        } else {
            datasets.append(ManifestEntry(id: datasetId, path: path ?? "", version: version ?? "", checksum: checksum))
        }
    }
}

struct ManifestEntry: Codable, Equatable, Identifiable {
    var id: String
    var path: String
    var version: String
    var checksum: String
}
