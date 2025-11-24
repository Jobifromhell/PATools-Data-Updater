import Foundation

struct Manifest: Codable, Equatable {
    var datasets: [String: ManifestEntry]

    init(datasets: [String: ManifestEntry] = [:]) {
        self.datasets = datasets
    }

    init(from decoder: Decoder) throws {
        if let keyedContainer = try? decoder.container(keyedBy: CodingKeys.self), keyedContainer.contains(.datasets) {
            if let dictionary = try? keyedContainer.decode([String: ManifestEntry].self, forKey: .datasets) {
                self.datasets = dictionary
                return
            }

            if let legacyArray = try? keyedContainer.decode([LegacyManifestEntry].self, forKey: .datasets) {
                self.datasets = Manifest.dictionary(from: legacyArray)
                return
            }

            let codingPath = keyedContainer.codingPath + [CodingKeys.datasets]
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Unsupported manifest datasets format")
            throw DecodingError.dataCorrupted(context)
        }

        if let dynamicContainer = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var dictionary: [String: ManifestEntry] = [:]
            for key in dynamicContainer.allKeys {
                let entry = try dynamicContainer.decode(ManifestEntry.self, forKey: key)
                dictionary[key.stringValue] = entry
            }
            if !dictionary.isEmpty {
                self.datasets = dictionary
                return
            }
        }

        let container = try decoder.singleValueContainer()
        if let legacyArray = try? container.decode([LegacyManifestEntry].self) {
            self.datasets = Manifest.dictionary(from: legacyArray)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported manifest format")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(datasets, forKey: .datasets)
    }

    mutating func updateEntry(for datasetId: String, checksum: String, version: String?, path: String?) {
        var entry = datasets[datasetId] ?? ManifestEntry(path: path ?? "", version: version ?? "", checksum: checksum)
        entry.checksum = checksum
        if let version {
            entry.version = version
        }
        if let path {
            entry.path = path
        }
        datasets[datasetId] = entry
    }
}

struct ManifestEntry: Codable, Equatable {
    var path: String
    var version: String
    var checksum: String
}

private extension Manifest {
    enum CodingKeys: String, CodingKey {
        case datasets
    }
}

private struct LegacyManifestEntry: Codable {
    var id: String
    var path: String
    var version: String
    var checksum: String
}

private extension Manifest {
    static func dictionary(from legacyArray: [LegacyManifestEntry]) -> [String: ManifestEntry] {
        Dictionary(uniqueKeysWithValues: legacyArray.map { entry in
            (entry.id, ManifestEntry(path: entry.path, version: entry.version, checksum: entry.checksum))
        })
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
