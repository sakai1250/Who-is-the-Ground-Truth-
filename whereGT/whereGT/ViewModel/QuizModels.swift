import Foundation

enum Winner: String, Codable {
    case human
    case ai
    case draw
}

struct QuizSummary: Codable {
    let total: Int
    let humanCorrect: Int
    let aiCorrect: Int
    let humanAccuracy: Double
    let aiAccuracy: Double
    let winner: Winner
    let comment: String
    let date: Date
}

struct QuizHistoryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let total: Int
    let humanCorrect: Int
    let aiCorrect: Int
    let humanAccuracy: Double
    let aiAccuracy: Double
    let winner: Winner
    let model: String?
}
