import Foundation

/// Lightweight loader for environment-style key/value pairs.
struct EnvLoader {
    static let shared = EnvLoader()

    /// Returns the value for a key, preferring process environment, then a bundled `.env` file.
    func value(for key: String) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
            return envValue
        }

        guard let url = Bundle.main.url(forResource: ".env", withExtension: nil),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let k = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let v = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if k == key { return v }
        }
        return nil
    }
}
