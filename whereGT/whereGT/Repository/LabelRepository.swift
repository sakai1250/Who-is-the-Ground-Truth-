import Foundation
import Combine

/// Loads and searches labels from the bundle or from class labels embedded in a CoreML model.
final class LabelRepository: ObservableObject {
    @Published private(set) var allLabels: [LabelItem] = []
    @Published private(set) var loadStatus: LabelLoadStatus = .idle

    func loadLabels(for model: VisionModelChoice, classLabels: [String]? = nil) {
        loadStatus = .loading

        // If the CoreML model already exposes its class labels (e.g. ImageNet-1K), prefer them.
        // When only placeholder labels (cls_0...) are provided, we still try to load a bundled file first.
        var pendingPlaceholder: [LabelItem]?
        if let classLabels, !classLabels.isEmpty {
            let parsed = Self.parse(rawLabels: classLabels)
            let isPlaceholder = parsed.allSatisfy { $0.primaryName.hasPrefix("cls_") }
            if !isPlaceholder {
                DispatchQueue.main.async { [weak self] in
                    self?.allLabels = parsed
                    self?.loadStatus = .success(count: parsed.count)
                }
                return
            } else {
                pendingPlaceholder = parsed
            }
        }

        let candidates: [(String, String)]
        switch model {
        case .deitSmall:
            // Prefer 1K labels when available; fall back to bundled 21K list.
            candidates = [("imagenet1k_labels", "txt"), ("label", "txt"), ("imagenet21k_labels", "txt")]
        case .vitSmall21k:
            candidates = [("label", "txt"), ("imagenet21k_labels", "txt")]
        }
        let url = candidates.compactMap { Bundle.main.url(forResource: $0.0, withExtension: $0.1) }.first

        guard let url else {
            let lookedFor = candidates.map { "\($0.0).\($0.1)" }.joined(separator: ", ")
            print("Label file not found in bundle (looked for \(lookedFor)).")
            if let pendingPlaceholder {
                DispatchQueue.main.async { [weak self] in
                    self?.allLabels = pendingPlaceholder
                    self?.loadStatus = .success(count: pendingPlaceholder.count)
                }
            } else {
                loadStatus = .failure("Label file not found in bundle.")
            }
            return
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let parsed = Self.parse(rawLabels: lines)
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

    private static func parse(rawLabels: [String]) -> [LabelItem] {
        rawLabels.enumerated().compactMap { idx, line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            // Support multiple label formats:
            // - "n00004475,organism, being"
            // - "0: 'tench, Tinca tinca'," (ImageNet-1K style)
            let rawNamePortion: String
            let explicitID: String?
            if let colonRange = trimmed.firstIndex(of: ":") {
                // Format with leading index and colon; strip quotes and trailing comma.
                explicitID = String(trimmed[..<colonRange]).trimmingCharacters(in: .whitespaces)
                var remainder = String(trimmed[trimmed.index(after: colonRange)...]).trimmingCharacters(in: .whitespaces)
                if remainder.hasPrefix("'") { remainder.removeFirst() }
                if remainder.hasSuffix(",") { remainder.removeLast() }
                if remainder.hasSuffix("'") { remainder.removeLast() }
                rawNamePortion = remainder
            } else {
                explicitID = nil
                rawNamePortion = trimmed
            }

            let parts = rawNamePortion
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

            guard !parts.isEmpty else { return nil }

            // If the ID is missing (e.g. labels coming from model metadata), synthesize one based on index later.
            let hasExplicitID = parts.count >= 2 && explicitID == nil
            let id: String
            if let explicitID, !explicitID.isEmpty {
                id = "cls_\(explicitID)"
            } else if hasExplicitID {
                id = parts[0]
            } else {
                id = "cls_\(idx)"
            }
            let primaryName = hasExplicitID ? parts[1] : parts[0]
            let alias = Array(parts.dropFirst(hasExplicitID ? 2 : 1))
            return LabelItem(id: id, primaryName: primaryName, alias: alias)
        }
    }
}

enum LabelLoadStatus: Equatable {
    case idle
    case loading
    case success(count: Int)
    case failure(String)
}
