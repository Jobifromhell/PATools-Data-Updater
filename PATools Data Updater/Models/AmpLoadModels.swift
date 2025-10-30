import Foundation

struct AmpLoadDataset: Codable, Equatable {
    var version: String
    var amplifiers: [Amplifier]

    init(version: String = "", amplifiers: [Amplifier] = []) {
        self.version = version
        self.amplifiers = amplifiers
    }

    static func empty() -> AmpLoadDataset {
        AmpLoadDataset(version: "", amplifiers: [])
    }

    func validate() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(message: "Amp Load version is required."))
        }

        if amplifiers.isEmpty {
            issues.append(.init(message: "At least one amplifier is required."))
        }

        for amplifier in amplifiers {
            if amplifier.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(message: "Each amplifier must have a name."))
            }
            if amplifier.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(message: "Amplifier \(amplifier.displayName) must include a brand."))
            }
            if amplifier.loads.isEmpty {
                issues.append(.init(message: "Amplifier \(amplifier.displayName) must have at least one load entry."))
            }
            for load in amplifier.loads {
                if load.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(message: "Amplifier \(amplifier.displayName) has a load without a model name."))
                }
                if load.total < 0 {
                    issues.append(.init(message: "Amplifier \(amplifier.displayName) load \(load.modelName) total must be >= 0."))
                }
                if load.perChannel < 0 {
                    issues.append(.init(message: "Amplifier \(amplifier.displayName) load \(load.modelName) per-channel must be >= 0."))
                }
            }
        }
        return issues
    }
}

struct Amplifier: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var brand: String
    var loads: [SpeakerLoad]

    init(id: UUID = UUID(), name: String = "", brand: String = "", loads: [SpeakerLoad] = []) {
        self.id = id
        self.name = name
        self.brand = brand
        self.loads = loads
    }

    var displayName: String {
        if !brand.isEmpty {
            return "\(brand) \(name)"
        }
        return name
    }

    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case loads
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.brand = try container.decode(String.self, forKey: .brand)
        let loadsDictionary = try container.decode([String: LoadSpecification].self, forKey: .loads)
        self.loads = loadsDictionary.map { key, value in
            SpeakerLoad(modelName: key, total: value.total, perChannel: value.perChannel)
        }.sorted { $0.modelName < $1.modelName }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(brand, forKey: .brand)
        let dictionary = Dictionary(uniqueKeysWithValues: loads.map { load in
            (load.modelName, LoadSpecification(total: load.total, perChannel: load.perChannel))
        })
        try container.encode(dictionary, forKey: .loads)
    }
    static func == (lhs: Amplifier, rhs: Amplifier) -> Bool {
        lhs.name == rhs.name && lhs.brand == rhs.brand && lhs.loads == rhs.loads
    }
}

struct SpeakerLoad: Identifiable, Hashable {
    var id: UUID = UUID()
    var modelName: String
    var total: Int
    var perChannel: Int

    init(id: UUID = UUID(), modelName: String = "", total: Int = 0, perChannel: Int = 0) {
        self.id = id
        self.modelName = modelName
        self.total = total
        self.perChannel = perChannel
    }
}

extension SpeakerLoad: Equatable {
    static func == (lhs: SpeakerLoad, rhs: SpeakerLoad) -> Bool {
        lhs.modelName == rhs.modelName && lhs.total == rhs.total && lhs.perChannel == rhs.perChannel
    }
}

private struct LoadSpecification: Codable, Equatable {
    var total: Int
    var perChannel: Int
}
