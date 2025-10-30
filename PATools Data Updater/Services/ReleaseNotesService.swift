import Foundation

final class ReleaseNotesService {
    private let formatter: DateFormatter

    init() {
        formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
    }

    func appendEntry(datasetId: String, version: String, date: Date, notes: String, to url: URL) throws {
        let fileManager = FileManager.default
        let header = "## \(datasetId) v\(version) - \(formatter.string(from: date))\n"
        let body = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        var content = "\n\(header)\n"
        if !body.isEmpty {
            content.append(body)
            content.append("\n")
        }
        if fileManager.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            if let data = content.data(using: .utf8) {
                handle.write(data)
            }
            try handle.close()
        } else {
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func loadEntries(from url: URL) throws -> [ReleaseNoteEntry] {
        let data = try String(contentsOf: url)
        var entries: [ReleaseNoteEntry] = []
        let sections = data.components(separatedBy: "\n## ").map { section -> String in
            if section.hasPrefix("## ") {
                return String(section.dropFirst(3))
            }
            return section
        }
        for section in sections {
            guard !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let lines = section.components(separatedBy: "\n")
            guard let firstLine = lines.first else { continue }
            let header = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = header.components(separatedBy: " v")
            guard components.count >= 2 else { continue }
            let datasetId = components[0]
            let versionAndDate = components[1].components(separatedBy: " - ")
            let version = versionAndDate.first ?? ""
            let dateString = versionAndDate.count > 1 ? versionAndDate[1] : ""
            let date = formatter.date(from: dateString) ?? Date()
            let notesLines = Array(lines.dropFirst())
            let notes = notesLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(ReleaseNoteEntry(datasetId: datasetId, version: version, date: date, notes: notes))
        }
        return entries.sorted { $0.date > $1.date }
    }
}
