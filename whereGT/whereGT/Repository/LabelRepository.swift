import Foundation
import Combine

/// Loads and searches ImageNet-21K labels stored in label.txt (or legacy imagenet21k_labels.txt) inside the app bundle.
final class LabelRepository: ObservableObject {
    @Published private(set) var allLabels: [LabelItem] = []
    @Published private(set) var loadStatus: LabelLoadStatus = .idle

    func loadLabels() {
        guard allLabels.isEmpty else {
            loadStatus = .success(count: allLabels.count)
            return
        }
        loadStatus = .loading

        let candidates = [("label", "txt"), ("imagenet21k_labels", "txt")]
        let url = candidates.compactMap { Bundle.main.url(forResource: $0.0, withExtension: $0.1) }.first

        guard let url else {
            print("Label file not found in bundle (looked for label.txt / imagenet21k_labels.txt).")
            loadStatus = .failure("Label file not found in bundle (label.txt).")
            return
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let parsed: [LabelItem] = lines.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                let parts = trimmed
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

                guard parts.count >= 2 else { return nil }
                let id = parts[0]
                let primaryName = parts[1]
                let alias = Array(parts.dropFirst(2))
                return LabelItem(id: id, primaryName: primaryName, alias: alias)
            }
            DispatchQueue.main.async { [weak self] in
                self?.allLabels = parsed
                self?.loadStatus = .success(count: parsed.count)
            }
        } catch {
            print("Failed to read labels: \(error)")
            loadStatus = .failure("Failed to read labels: \(error.localizedDescription)")
        }
    }

    func searchLabels(query: String, limit: Int = 20) -> [LabelItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        let filtered = allLabels.filter { item in
            if item.primaryName.contains(normalized) { return true }
            return item.alias.contains { $0.contains(normalized) }
        }
        return Array(filtered.prefix(limit))
    }
}

enum LabelLoadStatus: Equatable {
    case idle
    case loading
    case success(count: Int)
    case failure(String)
}
