import Foundation

struct AmpLoadDataset: Encodable, Equatable {
    var amplifiers: [Amplifier]

    init(amplifiers: [Amplifier]) {
        self.amplifiers = amplifiers
    }

    func validate() throws {
        var duplicatesByAmplifier: [String: [String]] = [:]

        for amplifier in amplifiers {
            let duplicates = amplifier.duplicateModelNames()
            if !duplicates.isEmpty {
                duplicatesByAmplifier[amplifier.name] = duplicates.sorted()
            }
        }

        if !duplicatesByAmplifier.isEmpty {
            throw ValidationError.duplicateModelNames(duplicatesByAmplifier)
        }
    }

    func encode(to encoder: Encoder) throws {
        try validate()

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amplifiers, forKey: .amplifiers)
    }

    private enum CodingKeys: String, CodingKey {
        case amplifiers
    }

    enum ValidationError: Error, Equatable, LocalizedError {
        case duplicateModelNames([String: [String]])

        var errorDescription: String? {
            switch self {
            case .duplicateModelNames(let mapping):
                let description = mapping
                    .sorted { $0.key < $1.key }
                    .map { amplifier, names in
                        let namesDescription = names.joined(separator: ", ")
                        return "\(amplifier): [\(namesDescription)]"
                    }
                    .joined(separator: "; ")
                return "Duplicate load model names detected for: \(description)."
            }
        }
    }
}

extension AmpLoadDataset {
    struct Amplifier: Encodable, Equatable {
        var name: String
        var loads: [Load]

        init(name: String, loads: [Load]) {
            self.name = name
            self.loads = loads
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)

            var loadsContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .loads)

            var seen = Set<String>()
            for load in loads {
                guard let key = DynamicCodingKey(stringValue: load.modelName) else { continue }
                if seen.insert(load.modelName).inserted {
                    try loadsContainer.encode(load, forKey: key)
                }
            }
        }

        func duplicateModelNames() -> Set<String> {
            var seen = Set<String>()
            var duplicates = Set<String>()

            for load in loads {
                if !seen.insert(load.modelName).inserted {
                    duplicates.insert(load.modelName)
                }
            }

            return duplicates
        }

        private enum CodingKeys: String, CodingKey {
            case name
            case loads
        }
    }
}

extension AmpLoadDataset.Amplifier {
    struct Load: Encodable, Equatable {
        var modelName: String
        var nominalImpedance: Double

        init(modelName: String, nominalImpedance: Double) {
            self.modelName = modelName
            self.nominalImpedance = nominalImpedance
        }

        private enum CodingKeys: String, CodingKey {
            case nominalImpedance
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(nominalImpedance, forKey: .nominalImpedance)
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
