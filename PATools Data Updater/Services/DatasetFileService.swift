import Foundation

final class DatasetFileService {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func loadAmpLoad(from url: URL) throws -> AmpLoadDataset {
        let data = try Data(contentsOf: url)
        return try decoder.decode(AmpLoadDataset.self, from: data)
    }

    func loadPrealignment(from url: URL) throws -> PrealignmentDataset {
        let data = try Data(contentsOf: url)
        return try decoder.decode(PrealignmentDataset.self, from: data)
    }

    func saveAmpLoad(_ dataset: AmpLoadDataset, to url: URL) throws {
        let data = try encoder.encode(dataset)
        try data.write(to: url, options: .atomic)
    }

    func savePrealignment(_ dataset: PrealignmentDataset, to url: URL) throws {
        let data = try encoder.encode(dataset)
        try data.write(to: url, options: .atomic)
    }

    func loadManifest(from url: URL) throws -> Manifest {
        let data = try Data(contentsOf: url)
        return try decoder.decode(Manifest.self, from: data)
    }

    func saveManifest(_ manifest: Manifest, to url: URL) throws {
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
    }
}
