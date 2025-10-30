import Foundation

struct PrealignmentDataset: Codable, Equatable {
    var version: String
    var combos: [PrealignmentCombo]

    init(version: String = "", combos: [PrealignmentCombo] = []) {
        self.version = version
        self.combos = combos
    }

    static func empty() -> PrealignmentDataset {
        PrealignmentDataset(version: "", combos: [])
    }

    func validate() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(message: "Pre-alignment version is required."))
        }
        if combos.isEmpty {
            issues.append(.init(message: "At least one combo is required."))
        }
        for combo in combos {
            if combo.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(message: "Each combo must have an identifier."))
            }
            if combo.speaker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(message: "Combo \(combo.id) must specify a speaker."))
            }
            if combo.presetLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(message: "Combo \(combo.id) requires a preset label."))
            }
            if combo.components.isEmpty {
                issues.append(.init(message: "Combo \(combo.id) must define at least one component."))
            }
            for component in combo.components {
                if component.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(message: "Combo \(combo.id) has a component without a role."))
                }
                if component.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(message: "Combo \(combo.id) has a component without a name."))
                }
                if component.presetLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(message: "Combo \(combo.id) component \(component.name) requires a preset label."))
                }
                if component.delay < 0 {
                    issues.append(.init(message: "Combo \(combo.id) component \(component.name) delay must be >= 0."))
                }
                if component.phase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(message: "Combo \(combo.id) component \(component.name) must specify a phase."))
                }
            }
        }
        return issues
    }
}

struct PrealignmentCombo: Codable, Equatable, Identifiable {
    var id: String
    var speaker: String
    var subSummary: String
    var presetLabel: String
    var components: [ComboComponent]

    init(id: String = "", speaker: String = "", subSummary: String = "", presetLabel: String = "", components: [ComboComponent] = []) {
        self.id = id
        self.speaker = speaker
        self.subSummary = subSummary
        self.presetLabel = presetLabel
        self.components = components
    }
}

struct ComboComponent: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var role: String
    var name: String
    var presetLabel: String
    var delay: Double
    var phase: String

    init(id: UUID = UUID(), role: String = "", name: String = "", presetLabel: String = "", delay: Double = 0, phase: String = "") {
        self.id = id
        self.role = role
        self.name = name
        self.presetLabel = presetLabel
        self.delay = delay
        self.phase = phase
    }

    enum CodingKeys: CodingKey {
        case role
        case name
        case presetLabel
        case delay
        case phase
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(String.self, forKey: .role)
        self.name = try container.decode(String.self, forKey: .name)
        self.presetLabel = try container.decode(String.self, forKey: .presetLabel)
        self.delay = try container.decode(Double.self, forKey: .delay)
        self.phase = try container.decode(String.self, forKey: .phase)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(name, forKey: .name)
        try container.encode(presetLabel, forKey: .presetLabel)
        try container.encode(delay, forKey: .delay)
        try container.encode(phase, forKey: .phase)
    }

    static func == (lhs: ComboComponent, rhs: ComboComponent) -> Bool {
        lhs.role == rhs.role && lhs.name == rhs.name && lhs.presetLabel == rhs.presetLabel && lhs.delay == rhs.delay && lhs.phase == rhs.phase
    }
}
