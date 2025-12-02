import Foundation

struct GameResult {
    let aiLabel: LabelItem
    let userLabel: LabelItem
    let groundTruthLabel: LabelItem?
    let isExactMatch: Bool
    let aiMatchesGroundTruth: Bool
    let userMatchesGroundTruth: Bool
    let timestamp: Date
}
