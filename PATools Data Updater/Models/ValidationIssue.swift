import Foundation

struct ValidationIssue: Identifiable, Hashable {
    let id = UUID()
    let message: String
}
