import CoreML
import UIKit

protocol AILabelProvider {
    var loadStatusDescription: String { get }
    var classLabels: [String]? { get }
    func predictLabel(for image: UIImage, from labels: [LabelItem]) -> LabelItem?
}

/// CoreML-backed label provider that tries to find any ImageNet-21K model in the bundle.
final class CoreMLImageNet21KLabelProvider: AILabelProvider {
    private let model: MLModel?
    private let imageInputName: String?
    private let imageConstraint: MLImageConstraint?
    private let fallbackSize = CGSize(width: 224, height: 224)
    /// Class labels embedded in the CoreML model (if any). Used to align label repository with the model output size.
    private(set) var classLabels: [String]?
    private(set) var loadStatusDescription: String = "Searching for CoreML model..."

    /// Candidate model base names (without extension). Kept for fast-path.
    private static let defaultCandidateModelNames = [
        "vit_small_patch16_224_in21k",
        "deit_small_patch16_224"
    ]
    private let candidateModelNames: [String]
    /// Prefer compiled .mlmodelc in the built app bundle, then raw .mlpackage (source).
    private let candidateExtensions = ["mlmodelc", "mlpackage"]

    init(preferredModelOrder: [String] = []) {
        var mergedOrder: [String] = []
        mergedOrder.append(contentsOf: preferredModelOrder)
        for name in Self.defaultCandidateModelNames where !mergedOrder.contains(name) {
            mergedOrder.append(name)
        }
        self.candidateModelNames = mergedOrder

        var loadedModel: MLModel?
        var inputName: String?
        var constraint: MLImageConstraint?
        var embeddedClassLabels: [String]?
        var fallbackClassCount: Int?

        // 共通の設定: CPU で実行（MPSGraph 非対応環境でも動かす）
        let cpuOnlyConfig = MLModelConfiguration()
        cpuOnlyConfig.computeUnits = .cpuOnly

        // 1) 既知のファイル名（高速経路）
        outer: for name in candidateModelNames {
            for ext in candidateExtensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    do {
                        let m = try MLModel(contentsOf: url, configuration: cpuOnlyConfig)
                        loadedModel = m
                        if let imageEntry = m.modelDescription.inputDescriptionsByName.first(where: { $0.value.type == MLFeatureType.image }) {
                            inputName = imageEntry.key
                            constraint = imageEntry.value.imageConstraint
                        }
                        embeddedClassLabels = Self.extractClassLabels(from: m.modelDescription.classLabels)
                        fallbackClassCount = Self.deriveClassCount(from: m)
                        loadStatusDescription = ""
                        break outer
                    } catch {
                        print("Failed to load \(url.lastPathComponent): \(error)")
                    }
                }
            }
        }

        // 2) バンドル全体から .mlmodel / .mlpackage を探索
        if loadedModel == nil {
            if let (url, m) = Self.findAnyModelInBundle(configuration: cpuOnlyConfig) {
                loadedModel = m
                if let imageEntry = m.modelDescription.inputDescriptionsByName.first(where: { $0.value.type == MLFeatureType.image }) {
                    inputName = imageEntry.key
                    constraint = imageEntry.value.imageConstraint
                }
                embeddedClassLabels = Self.extractClassLabels(from: m.modelDescription.classLabels)
                fallbackClassCount = Self.deriveClassCount(from: m)
                print("Loaded CoreML model at: \(url.lastPathComponent)")
                loadStatusDescription = ""
            } else {
                // Debug: list what we can actually see in the bundle
                let found = Self.allModelURLsInBundle()
                if found.isEmpty {
                    print("No .mlmodelc/.mlpackage files visible in bundle.")
                } else {
                    print("Bundle contains models but failed to load: \(found.map { $0.lastPathComponent })")
                }
            }
        }

        if loadedModel == nil {
            print("No CoreML model loaded.")
            loadStatusDescription = "No CoreML model loaded; prediction unavailable."
        }

        self.model = loadedModel
        self.imageInputName = inputName
        self.imageConstraint = constraint
        if let embeddedClassLabels, !embeddedClassLabels.isEmpty {
            self.classLabels = embeddedClassLabels
        } else if let count = fallbackClassCount, count > 0 {
            self.classLabels = (0..<count).map { "cls_\($0)" }
            loadStatusDescription += " (using \(count) placeholder labels)"
        } else {
            self.classLabels = nil
        }
    }

    func predictLabel(for image: UIImage, from labels: [LabelItem]) -> LabelItem? {
        guard let model, let inputName = imageInputName else {
            print("No CoreML model loaded.")
            loadStatusDescription = "Prediction skipped: no CoreML model loaded."
            return nil
        }

        let targetSize = CGSize(width: imageConstraint?.pixelsWide ?? Int(fallbackSize.width),
                                height: imageConstraint?.pixelsHigh ?? Int(fallbackSize.height))
        guard let pixelBuffer = pixelBuffer(from: image, size: targetSize) else {
            print("Failed to create pixel buffer.")
            loadStatusDescription = "Prediction failed: could not create pixel buffer."
            return nil
        }

        do {
            let feature = MLFeatureValue(pixelBuffer: pixelBuffer)
            let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: feature])
            let output = try model.prediction(from: provider)

            // Prefer classLabel output, else derive from classLabelProbs or logits MultiArray.
            if let predicted = output.featureValue(for: "classLabel")?.stringValue.lowercased(),
               let match = matchLabel(predicted: predicted, in: labels) {
                return match
            }

            if let probs = output.featureValue(for: "classLabelProbs")?.dictionaryValue as? [String: NSNumber],
               let best = probs.max(by: { $0.value.doubleValue < $1.value.doubleValue })?.key.lowercased(),
               let match = matchLabel(predicted: best, in: labels) {
                return match
            }

            if let logits = output.featureValue(for: "logits")?.multiArrayValue ?? firstMultiArray(from: output) {
                if logits.count != labels.count {
                    loadStatusDescription = "Prediction failed: logits count \(logits.count) != labels \(labels.count)"
                    return nil
                }
                if let topIndex = argmax(of: logits), topIndex < labels.count {
                    return labels[topIndex]
                }
            }
        } catch {
            print("Prediction failed: \(error)")
            loadStatusDescription = "Prediction failed: \(error.localizedDescription)"
        }

        return nil
    }

    private func matchLabel(predicted: String, in labels: [LabelItem]) -> LabelItem? {
        // primaryName 完全一致
        if let exact = labels.first(where: { $0.primaryName == predicted }) {
            return exact
        }
        // alias 完全一致
        if let aliasHit = labels.first(where: { $0.alias.contains(predicted) }) {
            return aliasHit
        }
        // 最後の手段: primaryName に部分一致（必要なければ削除）
        if let partial = labels.first(where: { $0.primaryName.contains(predicted) }) {
            return partial
        }
        return nil
    }

    /// Resizes a UIImage into a CVPixelBuffer suitable for CoreML input.
    private func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(size.width),
                                         Int(size.height),
                                         kCVPixelFormatType_32ARGB,
                                         attributes as CFDictionary,
                                         &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }

        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        let rect = CGRect(origin: .zero, size: size)
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: rect)
        } else {
            UIGraphicsPushContext(context)
            image.draw(in: rect)
            UIGraphicsPopContext()
        }

        return buffer
    }

    private static func findAnyModelInBundle(configuration: MLModelConfiguration) -> (URL, MLModel)? {
        guard let root = Bundle.main.resourceURL else { return nil }
        let fm = FileManager.default
        let exts = Set(["mlmodelc", "mlpackage"])
        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                let ext = url.pathExtension.lowercased()
                if exts.contains(ext) {
                    if let model = try? MLModel(contentsOf: url, configuration: configuration) {
                        return (url, model)
                    }
                }
            }
        }
        return nil
    }

    /// For debugging: list all model URLs visible to the bundle.
    private static func allModelURLsInBundle() -> [URL] {
        guard let root = Bundle.main.resourceURL else { return [] }
        let fm = FileManager.default
        var results: [URL] = []
        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                let ext = url.pathExtension.lowercased()
                if ext == "mlmodelc" || ext == "mlpackage" {
                    results.append(url)
                }
            }
        }
        return results
    }

    private func firstMultiArray(from output: MLFeatureProvider) -> MLMultiArray? {
        for name in output.featureNames {
            if let arr = output.featureValue(for: name)?.multiArrayValue {
                return arr
            }
        }
        return nil
    }

    private func argmax(of array: MLMultiArray) -> Int? {
        let count = array.count
        guard count > 0 else { return nil }
        var bestIndex = 0
        var bestValue = -Double.infinity
        for i in 0..<count {
            let v = array[i].doubleValue
            if v > bestValue {
                bestValue = v
                bestIndex = i
            }
        }
        return bestIndex
    }

    private static func extractClassLabels(from raw: Any?) -> [String]? {
        if let strings = raw as? [String] {
            return strings
        }
        if let numbers = raw as? [NSNumber] {
            return numbers.map { $0.stringValue }
        }
        return nil
    }

    private static func deriveClassCount(from model: MLModel) -> Int? {
        // Try logits output, otherwise any multiArray output.
        let outputs = model.modelDescription.outputDescriptionsByName
        if let logits = outputs["logits"]?.multiArrayConstraint,
           let count = elementCount(from: logits.shape) {
            return count
        }
        if let any = outputs.values.compactMap({ $0.multiArrayConstraint }).first,
           let count = elementCount(from: any.shape) {
            return count
        }
        return nil
    }

    private static func elementCount(from shape: [NSNumber]) -> Int? {
        let dims = shape.map { $0.intValue }.filter { $0 > 0 }
        guard !dims.isEmpty else { return nil }
        return dims.reduce(1, *)
    }
}
