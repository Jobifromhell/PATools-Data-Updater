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
            return appendCodingPath(to: context.debugDescription, codingPath: context.codingPath)
        case let .keyNotFound(key, context):
            let base = "Missing key '\(key.stringValue)': \(context.debugDescription)"
            return appendCodingPath(to: base, codingPath: context.codingPath)
        case let .typeMismatch(type, context):
            if let manifestMessage = manifestTypeMismatchMessage(context: context) {
                return manifestMessage
            }
            let base = "Type mismatch for \(type): \(context.debugDescription)"
            return appendCodingPath(to: base, codingPath: context.codingPath)
        case let .valueNotFound(type, context):
            let base = "Missing value for \(type): \(context.debugDescription)"
            return appendCodingPath(to: base, codingPath: context.codingPath)
        @unknown default:
            return error.localizedDescription
        }
    }

    private func appendCodingPath(to message: String, codingPath: [CodingKey]) -> String {
        guard let path = codingPathDescription(from: codingPath) else {
            return message
        }
        return "\(message) at coding path '\(path)'"
    }

    private func codingPathDescription(from codingPath: [CodingKey]) -> String? {
        guard !codingPath.isEmpty else { return nil }
        return codingPath.map { key in
            if let index = key.intValue {
                return "[\(index)]"
            } else {
                return key.stringValue
            }
        }.joined(separator: ".")
    }

    private func manifestTypeMismatchMessage(context: DecodingError.Context) -> String? {
        guard let codingPath = codingPathDescription(from: context.codingPath), codingPath == "datasets" else {
            return nil
        }
        let expected = "Expected 'datasets' to be a dictionary keyed by dataset ids"
        let base = "\(expected): \(context.debugDescription)"
        return appendCodingPath(to: base, codingPath: context.codingPath)
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
