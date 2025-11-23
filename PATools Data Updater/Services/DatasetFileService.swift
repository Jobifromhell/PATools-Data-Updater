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
        do {
            return try decoder.decode(Manifest.self, from: data)
        } catch let decodingError as DecodingError {
            let message = decodingMessage(from: decodingError)
            throw DatasetFileServiceError.manifestDecodingFailed(path: url.path, message: message)
        }
    }

    func saveManifest(_ manifest: Manifest, to url: URL) throws {
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    private func decodingMessage(from error: DecodingError) -> String {
        switch error {
        case let .dataCorrupted(context):
            return context.debugDescription
        case let .keyNotFound(key, context):
            return "Missing key '\(key.stringValue)': \(context.debugDescription)"
        case let .typeMismatch(type, context):
            return "Type mismatch for \(type): \(context.debugDescription)"
        case let .valueNotFound(type, context):
            return "Missing value for \(type): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}

enum DatasetFileServiceError: LocalizedError {
    case manifestDecodingFailed(path: String, message: String)

    var errorDescription: String? {
        switch self {
        case let .manifestDecodingFailed(path, message):
            return "Failed to decode manifest at \(path): \(message)"
        }
    }
}
