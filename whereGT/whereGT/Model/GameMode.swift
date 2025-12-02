import Foundation

enum GameMode: String, CaseIterable, Identifiable {
    case pixabaySearch
    case albumBoss
    case labelRoulette

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pixabaySearch:
            return "ストックサファリ"
        case .albumBoss:
            return "アルバムの刺客"
        case .labelRoulette:
            return "ラベルルーレット"
        }
    }

    var description: String {
        switch self {
        case .pixabaySearch:
            return "Pixabay を自由に漁って AI を挑発するフリーローム。"
        case .albumBoss:
            return "カメラロールの秘密兵器で AI に一撃を食らわせるボス戦。"
        case .labelRoulette:
            return "Web API が ImageNet-21K のラベルをランダム抽選、謎のお題で殴り合う運試しモード。"
        }
    }

    var statusHint: String {
        switch self {
        case .pixabaySearch:
            return "Pixabay で好きなお題を探して勝負しよう。"
        case .albumBoss:
            return "アルバムから1枚選んで AI に叩きつけよう。"
        case .labelRoulette:
            return "「おみくじ」を引いて、謎ラベル由来の画像で勝負！"
        }
    }
}

enum VisionModelChoice: String, CaseIterable, Identifiable {
    case deitSmall = "deit_small_patch16_224"
    case vitSmall21k = "vit_small_patch16_224_in21k"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deitSmall:
            return "DeiT Small"
        case .vitSmall21k:
            return "ViT Small IN21K"
        }
    }

    var hypeLine: String {
        switch self {
        case .deitSmall:
            return "蒸留で鍛えたストリートファイター。軽快＆キレ味鋭いパンチ担当。"
        case .vitSmall21k:
            return "教科書通りの優等生。ImageNet-21K でみっちり鍛えた本家本元。"
        }
    }

    /// Preferred CoreML model file names (without extension) in order.
    var preferredModelNames: [String] {
        [rawValue]
    }
}
