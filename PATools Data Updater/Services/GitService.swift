import Foundation

struct GitConfiguration: Equatable {
    var repositoryPath: String
    var remote: String
    var branch: String
    var personalAccessToken: String
    var pushAutomatically: Bool

    init(repositoryPath: String = "", remote: String = "origin", branch: String = "main", personalAccessToken: String = "", pushAutomatically: Bool = false) {
        self.repositoryPath = repositoryPath
        self.remote = remote
        self.branch = branch
        self.personalAccessToken = personalAccessToken
        self.pushAutomatically = pushAutomatically
    }
}

final class GitService {
    func commitAndPush(files: [URL], message: String, configuration: GitConfiguration) throws -> [String] {
        guard !configuration.repositoryPath.isEmpty else { return [] }
        var outputs: [String] = []
        let addArguments = ["add"] + files.map { $0.path }
        outputs.append(try runGit(arguments: addArguments, configuration: configuration))
        outputs.append(try runGit(arguments: ["commit", "-m", message], configuration: configuration))
        if configuration.pushAutomatically {
            outputs.append(try push(configuration: configuration))
        }
        return outputs
    }

    private func push(configuration: GitConfiguration) throws -> String {
        var arguments: [String] = ["push"]
        let remote = configuration.remoteWithCredentials
        if let remote = remote {
            arguments.append(remote)
        } else {
            arguments.append(configuration.remote)
        }
        arguments.append(configuration.branch)
        return try runGit(arguments: arguments, configuration: configuration)
    }

    private func runGit(arguments: [String], configuration: GitConfiguration) throws -> String {
        guard FileManager.default.fileExists(atPath: configuration.repositoryPath) else {
            throw GitServiceError.repositoryNotFound(path: configuration.repositoryPath)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: configuration.repositoryPath)
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        if !configuration.personalAccessToken.isEmpty {
            environment["GIT_TOKEN"] = configuration.personalAccessToken
        }
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw GitServiceError.processLaunchFailed(underlyingError: error)
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw GitServiceError.commandFailed(arguments: arguments, output: output)
        }
        return output
    }
}

private extension GitConfiguration {
    var remoteWithCredentials: String? {
        guard remote.lowercased().hasPrefix("http"), !personalAccessToken.isEmpty else { return nil }
        guard let url = URL(string: remote) else { return nil }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if components.user == nil || components.user?.isEmpty == true {
            components.user = "x-access-token"
        }
        components.password = personalAccessToken
        return components.url?.absoluteString
    }
}

enum GitServiceError: LocalizedError {
    case commandFailed(arguments: [String], output: String)
    case repositoryNotFound(path: String)
    case processLaunchFailed(underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(arguments, output):
            return "git \(arguments.joined(separator: " ")) failed: \(output)"
        case let .repositoryNotFound(path):
            return "Git repository not found at path: \(path). Update the repository path in Settings."
        case let .processLaunchFailed(error):
            return "Failed to launch git: \(error.localizedDescription)"
        }
    }
}
