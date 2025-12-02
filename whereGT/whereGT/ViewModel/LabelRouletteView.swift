import SwiftUI

struct LabelRouletteView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modelPicker

                Divider()

                quizControlSection
                currentImageSection
                aiLabelSection

                userAnswerSection
                judgeSection
                resultSection

                statusSection
            }
            .padding()
            .font(.system(size: 16))
        }
        .navigationTitle("Label Roulette")
        .toolbar {
            NavigationLink {
                QuizHistoryView(viewModel: viewModel)
            } label: {
                Label("History", systemImage: "clock")
            }
        }
    }

    private var modelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("モデルガレージ")
                .font(.headline)
            Picker("AI Model", selection: $viewModel.selectedModel) {
                ForEach(VisionModelChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedModel) { _, newValue in
                viewModel.selectModel(newValue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedModel.hypeLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.aiModelStatusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quizControlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ラベルルーレット（人類 vs AI）")
                .font(.headline)
            Text("Web API が ImageNet-21K のラベルをランダム抽選。謎ラベル由来の画像で AI と一騎打ち。")
                .font(.caption)
                .foregroundStyle(.secondary)

            // クイズ開始ボタン（5問 / 10問）
            if !viewModel.quizIsActive && viewModel.quizSummary == nil {
                HStack {
                    Button {
                        viewModel.startRouletteQuiz(totalQuestions: 5)
                    } label: {
                        Label("5問で勝負", systemImage: "number")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoadingPixabay)

                    Button {
                        viewModel.startRouletteQuiz(totalQuestions: 10)
                    } label: {
                        Label("10問で勝負", systemImage: "number")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoadingPixabay)
                }
            }

            // 進行状況
            if viewModel.quizIsActive {
                HStack {
                    Text("進行状況: 第\(viewModel.quizCurrentIndex)問 / 全\(viewModel.quizTotalQuestions)問")
                    Spacer()
                    if viewModel.isLoadingPixabay {
                        ProgressView()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                // 次の問題へ（判定後に表示）
                if viewModel.lastResult != nil && viewModel.quizCurrentIndex < viewModel.quizTotalQuestions {
                    Button {
                        viewModel.nextRouletteQuestion()
                    } label: {
                        Label("次の問題へ", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // ステータス
            Text(viewModel.challengeStatusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            // 結果サマリー（クイズ終了後）
            if let summary = viewModel.quizSummary {
                VStack(alignment: .leading, spacing: 8) {
                    Text("結果発表")
                        .font(.title3.weight(.semibold))
                    Text("人類: \(summary.humanCorrect)/\(summary.total)（\(Int((summary.humanAccuracy * 100.0).rounded()))%）")
                    Text("AI: \(summary.aiCorrect)/\(summary.total)（\(Int((summary.aiAccuracy * 100.0).rounded()))%）")
                    Text("勝者: \(summary.winner == .human ? "人類" : (summary.winner == .ai ? "AI" : "引き分け"))")
                        .font(.headline)
                    Text(summary.comment)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button {
                            viewModel.startRouletteQuiz(totalQuestions: summary.total)
                        } label: {
                            Label("同じ問数で再戦", systemImage: "gobackward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.startRouletteQuiz(totalQuestions: 5)
                        } label: {
                            Label("5問で再戦", systemImage: "number")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.startRouletteQuiz(totalQuestions: 10)
                        } label: {
                            Label("10問で再戦", systemImage: "number")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var currentImageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Image")
                .font(.headline)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 240)
                if let gameImage = viewModel.currentImage {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(uiImage: gameImage.uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text(gameImage.sourceDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let label = viewModel.challengeLabel {
                            Text("秘密のお題をロック中 (ID: \(label.id) / 答えは判定で公開)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding()
                } else {
                    Text("No image selected yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aiLabelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI's guess")
                .font(.headline)
            if let aiLabel = viewModel.aiLabel {
                Text(labelDisplayText(for: aiLabel))
                    .font(.title3.weight(.semibold))
            } else {
                Text("No prediction yet.")
                    .foregroundStyle(.secondary)
            }
            if viewModel.isRunningPrediction {
                ProgressView()
                    .padding(.vertical, 4)
            }
            Text(viewModel.predictionStatusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.aiLabel == nil {
                Text("Model: \(viewModel.selectedModel.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var userAnswerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your answer (type to search labels)")
                .font(.headline)
            TextField("Start typing a label", text: $viewModel.userQuery)
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.userQuery) { _, newValue in
                    viewModel.updateUserQuery(newValue)
                }

            if !viewModel.searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.searchResults) { (item: LabelItem) in
                        Button {
                            viewModel.selectedUserLabel = item
                            viewModel.userQuery = item.primaryName
                        } label: {
                            HStack {
                                Text(labelDisplayText(for: item))
                                Spacer()
                                if viewModel.selectedUserLabel?.id == item.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("お題は非公開。判定ボタンでネタバレ＆勝敗が決まる。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var judgeSection: some View {
        Button {
            viewModel.judge()
        } label: {
            Text("判定してネタバレ")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.aiLabel == nil || viewModel.selectedUserLabel == nil)
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let result = viewModel.lastResult {
                if let truth = result.groundTruthLabel {
                    Text("Ground Truth: \(labelDisplayText(for: truth))")
                        .font(.headline)
                    Text(result.userMatchesGroundTruth ? "You nailed the secret label!" : "You missed the secret label.")
                        .foregroundStyle(result.userMatchesGroundTruth ? .green : .orange)
                    Text(result.aiMatchesGroundTruth ? "AI hit the target." : "AI missed the target.")
                        .foregroundStyle(result.aiMatchesGroundTruth ? .green : .orange)
                    if !result.isExactMatch {
                        Text("AI: \(result.aiLabel.primaryName) / You: \(result.userLabel.primaryName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if result.isExactMatch {
                    Text("Perfect match – you and the model agree.")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    Text("Disagreement detected.")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text("AI: \(result.aiLabel.primaryName)")
                    Text("You: \(result.userLabel.primaryName)")
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Load / prediction status")
                .font(.headline)
            statusRow(title: "Mode", message: viewModel.gameMode.statusHint)
            statusRow(title: "Roulette", message: viewModel.challengeStatusMessage)
            statusRow(title: "Labels", message: viewModel.labelStatusMessage)
            statusRow(title: "Model", message: viewModel.aiModelStatusMessage)
            statusRow(title: "Prediction", message: viewModel.predictionStatusMessage)
        }
        .padding(.vertical, 4)
    }

    private func statusRow(title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func labelDisplayText(for label: LabelItem) -> String {
        if let alias = label.alias.first, !alias.isEmpty {
            return "\(label.primaryName) (\(alias))"
        }
        return label.primaryName
    }
}
