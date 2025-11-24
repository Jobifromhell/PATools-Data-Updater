import Foundation

struct GitConfiguration: Equatable {
    var repositoryPath: String
    var remote: String
    var branch: String
    var personalAccessToken: String
    var pushAutomatically: Bool
    var gitExecutablePath: String

    init(
        repositoryPath: String = "",
        remote: String = "origin",
        branch: String = "main",
        personalAccessToken: String = "",
        pushAutomatically: Bool = false,
        gitExecutablePath: String = ""
    ) {
        self.repositoryPath = repositoryPath
        self.remote = remote
        self.branch = branch
        self.personalAccessToken = personalAccessToken
        self.pushAutomatically = pushAutomatically
        self.gitExecutablePath = gitExecutablePath
    }
}

final class GitService {
    private var cachedExecutableURL: URL?

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

    func testConnection(configuration: GitConfiguration) throws -> String {
        guard !configuration.repositoryPath.isEmpty else {
            throw GitServiceError.repositoryNotFound(path: configuration.repositoryPath)
        }
        var arguments = ["ls-remote"]
        if let remoteWithCredentials = configuration.remoteWithCredentials {
            arguments.append(remoteWithCredentials)
        } else {
            arguments.append(configuration.remote)
        }
        if !configuration.branch.isEmpty {
            arguments.append(configuration.branch)
        }
        return try runGit(arguments: arguments, configuration: configuration)
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
        let executableURL = try resolveGitExecutable(from: configuration)
        process.executableURL = executableURL
        process.arguments = arguments
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
            if output.lowercased().contains("xcrun: error:") {
                self.cachedExecutableURL = nil
                throw GitServiceError.gitExecutableBlockedBySandbox(output: output)
            }
            throw GitServiceError.commandFailed(arguments: arguments, output: output)
        }
        return output
    }

    private func resolveGitExecutable(from configuration: GitConfiguration) throws -> URL {
        if let cachedExecutableURL, FileManager.default.isExecutableFile(atPath: cachedExecutableURL.path) {
            if configuration.gitExecutablePath.isEmpty || cachedExecutableURL.path == configuration.gitExecutablePath {
                return cachedExecutableURL
            } else {
                self.cachedExecutableURL = nil
            }
        }

        let fileManager = FileManager.default
        var candidates: [String] = []
        if let explicitPath = configuration.effectiveGitExecutablePath {
            guard fileManager.isExecutableFile(atPath: explicitPath) else {
                throw GitServiceError.gitExecutableNotFound(explicitPath)
            }
            candidates.append(explicitPath)
        }
        candidates.append(contentsOf: GitService.defaultGitExecutableCandidates)

        for path in candidates where fileManager.isExecutableFile(atPath: path) {
            let url = URL(fileURLWithPath: path)
            self.cachedExecutableURL = url
            return url
        }

        throw GitServiceError.gitExecutableNotFound(configuration.gitExecutablePath)
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

    var effectiveGitExecutablePath: String? {
        let trimmed = gitExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum GitServiceError: LocalizedError {
    case commandFailed(arguments: [String], output: String)
    case repositoryNotFound(path: String)
    case processLaunchFailed(underlyingError: Error)
    case gitExecutableNotFound(String)
    case gitExecutableBlockedBySandbox(output: String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(arguments, output):
            return "git \(arguments.joined(separator: " ")) failed: \(output)"
        case let .repositoryNotFound(path):
            return "Git repository not found at path: \(path). Update the repository path in Settings."
        case let .processLaunchFailed(error):
            return "Failed to launch git: \(error.localizedDescription)"
        case let .gitExecutableNotFound(path):
            if path.isEmpty {
                return "Git executable not found. Set the Git executable path in Settings to a non-sandboxed git binary (for example, /Library/Developer/CommandLineTools/usr/bin/git)."
            } else {
                return "Git executable not found at \(path). Choose a valid git binary in Settings."
            }
        case let .gitExecutableBlockedBySandbox(output):
            return "The selected git binary is blocked by the App Sandbox: \(output). Choose a Command Line Tools git binary (e.g. /Library/Developer/CommandLineTools/usr/bin/git) in Settings."
        }
    }
}

private extension GitService {
    static let defaultGitExecutableCandidates: [String] = [
        "/Library/Developer/CommandLineTools/usr/bin/git",
        "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
        "/Applications/Xcode.app/Contents/Developer/usr/libexec/git-core/git",
        "/usr/local/bin/git",
        "/opt/homebrew/bin/git",
        "/usr/bin/git"
    ]
}
