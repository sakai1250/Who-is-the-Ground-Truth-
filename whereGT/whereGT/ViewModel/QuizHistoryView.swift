import SwiftUI

struct QuizHistoryView: View {
    @ObservedObject var viewModel: GameViewModel

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }

    var body: some View {
        List {
            if viewModel.quizHistory.isEmpty {
                Text("まだ戦績がありません。ラベルルーレットで勝負してみよう！")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.quizHistory) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: iconName(for: entry.winner))
                            .foregroundStyle(color(for: entry.winner))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateFormatter.string(from: entry.date))
                                .font(.subheadline.weight(.semibold))
                            Text("人類 \(entry.humanCorrect)/\(entry.total)（\(Int((entry.humanAccuracy * 100.0).rounded()))%） / AI \(entry.aiCorrect)/\(entry.total)（\(Int((entry.aiAccuracy * 100.0).rounded()))%）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let model = entry.model {
                                Text("Model: \(model)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(winnerText(for: entry.winner))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(color(for: entry.winner))
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("戦績")
    }

    private func iconName(for winner: Winner) -> String {
        switch winner {
        case .human: return "person.fill.checkmark"
        case .ai:    return "cpu"
        case .draw:  return "equal"
        }
    }

    private func color(for winner: Winner) -> Color {
        switch winner {
        case .human: return .green
        case .ai:    return .orange
        case .draw:  return .blue
        }
    }

    private func winnerText(for winner: Winner) -> String {
        switch winner {
        case .human: return "人類"
        case .ai:    return "AI"
        case .draw:  return "引き分け"
        }
    }
}
