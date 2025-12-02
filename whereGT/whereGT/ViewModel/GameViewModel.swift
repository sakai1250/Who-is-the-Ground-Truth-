import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    @Published var gameMode: GameMode = .pixabaySearch {
        didSet { handleModeChange(from: oldValue) }
    }
    @Published var selectedModel: VisionModelChoice
    @Published var currentImage: GameImage?
    @Published var aiLabel: LabelItem?
    @Published var labelStatusMessage: String = "Labels not loaded"
    @Published var aiModelStatusMessage: String
    @Published var predictionStatusMessage: String = "Waiting for image"
    @Published var isRunningPrediction: Bool = false
    @Published var challengeLabel: LabelItem?
    @Published var challengeStatusMessage: String

    @Published var userQuery: String = ""
    @Published var searchResults: [LabelItem] = []
    @Published var selectedUserLabel: LabelItem?

    @Published var lastResult: GameResult?

    @Published var pixabayQuery: String = ""
    @Published var pixabayResults: [PixabayImage] = []
    @Published var isLoadingPixabay: Bool = false
    @Published var pixabayErrorMessage: String?

    // ラベルルーレットのクイズ状態
    @Published var quizIsActive: Bool = false
    @Published var quizTotalQuestions: Int = 0
    @Published var quizCurrentIndex: Int = 0   // 1-based
    @Published var quizResults: [GameResult] = []
    @Published var quizSummary: QuizSummary?
    @Published var quizHistory: [QuizHistoryEntry] = []

    private let labelRepository: LabelRepository
    private var aiLabelProvider: AILabelProvider
    private let pixabayClient: PixabayClient

    private var cancellables = Set<AnyCancellable>()

    private static let quizHistoryKey = "quizHistory.v1"

    init(labelRepository: LabelRepository,
         pixabayClient: PixabayClient,
         initialModel: VisionModelChoice = .deitSmall) {
        self.labelRepository = labelRepository
        self.selectedModel = initialModel
        self.aiLabelProvider = CoreMLImageNet21KLabelProvider(preferredModelOrder: initialModel.preferredModelNames)
        self.pixabayClient = pixabayClient
        self.aiModelStatusMessage = aiLabelProvider.loadStatusDescription
        self.challengeStatusMessage = GameMode.pixabaySearch.statusHint
        self.quizHistory = Self.loadQuizHistory()

        // ラベル読み込みを開始し、進捗も監視
        labelRepository.$loadStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.labelStatusMessage = Self.labelStatusText(from: status)
            }
            .store(in: &cancellables)

        labelRepository.loadLabels(for: initialModel, classLabels: aiLabelProvider.classLabels)

        // ラベルが入ったら、自動で検索候補/推論を更新
        labelRepository.$allLabels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] labels in
                guard let self else { return }
                if !labels.isEmpty {
                    if !self.userQuery.isEmpty {
                        self.searchResults = self.labelRepository.searchLabels(query: self.userQuery)
                    }
                    self.attemptPredictionIfPossible()
                }
            }
            .store(in: &cancellables)
    }

    func selectModel(_ choice: VisionModelChoice) {
        if selectedModel != choice {
            selectedModel = choice
        }
        aiLabelProvider = CoreMLImageNet21KLabelProvider(preferredModelOrder: choice.preferredModelNames)
        aiModelStatusMessage = aiLabelProvider.loadStatusDescription
        aiLabel = nil
        predictionStatusMessage = currentImage == nil ? "Waiting for image" : "Waiting for labels"
        labelRepository.loadLabels(for: choice, classLabels: aiLabelProvider.classLabels)
        searchResults = []
        selectedUserLabel = nil
        if currentImage != nil {
            attemptPredictionIfPossible()
        }
    }

    func searchPixabay() {
        let query = pixabayQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isLoadingPixabay = true
        pixabayErrorMessage = nil
        Task {
            do {
                let images = try await pixabayClient.searchImages(query: query)
                await MainActor.run {
                    self.pixabayResults = images
                    self.isLoadingPixabay = false
                    self.pixabayErrorMessage = images.isEmpty ? "No results found." : nil
                }
            } catch {
                await MainActor.run {
                    self.pixabayResults = []
                    self.isLoadingPixabay = false
                    self.pixabayErrorMessage = "Failed to load images. Please try again."
                }
            }
        }
    }

    // 単発おみくじ（クイズ中では使わない）
    func startLabelRouletteRound() {
        guard gameMode == .labelRoulette else { return }
        guard !labelRepository.allLabels.isEmpty else {
            challengeStatusMessage = "ラベルがまだ読み込み中。少し待ってね。"
            return
        }
        guard !isLoadingPixabay else { return }
        fetchRandomRouletteImage(forQuiz: false)
    }

    // クイズ開始（5問 or 10問）
    func startRouletteQuiz(totalQuestions: Int) {
        guard gameMode == .labelRoulette else { return }
        guard !labelRepository.allLabels.isEmpty else {
            challengeStatusMessage = "ラベルがまだ読み込み中。少し待ってね。"
            return
        }
        guard !isLoadingPixabay else { return }

        quizIsActive = true
        quizTotalQuestions = totalQuestions
        quizCurrentIndex = 1
        quizResults = []
        quizSummary = nil
        lastResult = nil
        selectedUserLabel = nil
        userQuery = ""
        challengeStatusMessage = "クイズ開始！第1問の画像を探索中…"
        fetchRandomRouletteImage(forQuiz: true)
    }

    // 次の問題へ（クイズ中のみ）
    func nextRouletteQuestion() {
        guard quizIsActive, gameMode == .labelRoulette else { return }
        guard quizCurrentIndex < quizTotalQuestions else {
            finalizeRouletteQuiz()
            return
        }
        quizCurrentIndex += 1
        lastResult = nil
        selectedUserLabel = nil
        userQuery = ""
        challengeStatusMessage = "第\(quizCurrentIndex)問の画像を探索中…"
        fetchRandomRouletteImage(forQuiz: true)
    }

    // 判定
    func judge() {
        if gameMode == .labelRoulette && challengeLabel == nil {
            challengeStatusMessage = "まずおみくじを回してね。"
            return
        }
        guard let aiLabel, let selectedUserLabel else { return }
        let groundTruth = gameMode == .labelRoulette ? challengeLabel : nil
        let result = GameResult(aiLabel: aiLabel,
                                userLabel: selectedUserLabel,
                                groundTruthLabel: groundTruth,
                                isExactMatch: aiLabel.id == selectedUserLabel.id,
                                aiMatchesGroundTruth: groundTruth?.id == aiLabel.id,
                                userMatchesGroundTruth: groundTruth?.id == selectedUserLabel.id,
                                timestamp: Date())
        lastResult = result

        // クイズ進行
        if quizIsActive && gameMode == .labelRoulette {
            quizResults.append(result)
            if quizCurrentIndex >= quizTotalQuestions {
                finalizeRouletteQuiz()
            } else {
                challengeStatusMessage = "第\(quizCurrentIndex)問の判定完了。次の問題へ進もう。"
            }
        }
    }

    // MARK: - Helpers

    private func attemptPredictionIfPossible() {
        guard let image = currentImage?.uiImage else {
            predictionStatusMessage = "Waiting for image"
            return
        }

        guard !labelRepository.allLabels.isEmpty else {
            predictionStatusMessage = "Waiting for labels (\(labelStatusMessage))"
            return
        }

        isRunningPrediction = true
        predictionStatusMessage = "Running prediction..."
        let prediction = aiLabelProvider.predictLabel(for: image, from: labelRepository.allLabels)
        aiLabel = prediction
        aiModelStatusMessage = aiLabelProvider.loadStatusDescription
        isRunningPrediction = false
        predictionStatusMessage = prediction != nil ? "Prediction complete" : "Prediction failed (see model status)"
    }

    private func handleModeChange(from oldValue: GameMode) {
        pixabayQuery = ""
        pixabayResults = []
        pixabayErrorMessage = nil
        selectedUserLabel = nil
        userQuery = ""
        searchResults = []
        aiLabel = nil
        lastResult = nil
        currentImage = nil
        isLoadingPixabay = false
        isRunningPrediction = false
        if oldValue != gameMode {
            challengeLabel = nil
        }
        // クイズ状態をリセット
        quizIsActive = false
        quizTotalQuestions = 0
        quizCurrentIndex = 0
        quizResults = []
        quizSummary = nil

        challengeStatusMessage = gameMode.statusHint
        predictionStatusMessage = "Waiting for image"
        aiModelStatusMessage = aiLabelProvider.loadStatusDescription
    }

    private static func labelStatusText(from status: LabelLoadStatus) -> String {
        switch status {
        case .idle:
            return "Labels not loaded"
        case .loading:
            return "Loading labels..."
        case .success(let count):
            return "Loaded \(count) labels"
        case .failure(let message):
            return "Label load failed: \(message)"
        }
    }

    // ランダムにお題を選び、Pixabay から画像を取得してセット
    private func fetchRandomRouletteImage(forQuiz: Bool) {
        challengeStatusMessage = forQuiz ? "第\(quizCurrentIndex)問：ラベルおみくじ回転中..." : "ラベルおみくじ回転中..."
        pixabayErrorMessage = nil

        let label = labelRepository.allLabels.randomElement()!
        challengeLabel = label
        isLoadingPixabay = true

        Task {
            do {
                let images = try await pixabayClient.searchImages(query: label.primaryName)
                guard let image = images.randomElement() else {
                    await MainActor.run {
                        self.challengeStatusMessage = forQuiz ? "第\(self.quizCurrentIndex)問：画像が見つからず…引き直そう。" : "画像が見つからず…もう一回引いてみよう。"
                        self.isLoadingPixabay = false
                    }
                    return
                }
                let uiImage = try await downloadPixabayImage(image)
                await MainActor.run {
                    let description = "Label Roulette: \(label.primaryName)"
                    self.updateImage(uiImage, sourceType: .pixabay, description: "")
                    self.challengeStatusMessage = forQuiz ? "第\(self.quizCurrentIndex)問：お題は秘密。AI とあなた、どちらが当てる？" : "お題は秘密。AI とあなた、どちらが当てる？"
                    self.isLoadingPixabay = false
                }
            } catch {
                await MainActor.run {
                    self.challengeStatusMessage = forQuiz ? "第\(self.quizCurrentIndex)問：ランダム画像の取得に失敗。リトライしてね。" : "ランダム画像の取得に失敗。リトライしてね。"
                    self.pixabayErrorMessage = "Failed to load random challenge."
                    self.isLoadingPixabay = false
                }
            }
        }
    }

    func selectPixabayImage(_ image: PixabayImage, descriptionOverride: String? = nil) {
        isLoadingPixabay = true
        pixabayErrorMessage = nil

        Task {
            do {
                let uiImage = try await downloadPixabayImage(image)
                await MainActor.run {
                    let description = descriptionOverride ?? "Pixabay: \(image.user) / \(image.id)"
                    self.updateImage(uiImage, sourceType: .pixabay, description: description)
                    self.isLoadingPixabay = false
                    if self.gameMode == .labelRoulette {
                        self.challengeStatusMessage = "謎ラベルの画像を連れてきた。判定で答え合わせしよう。"
                    }
                }
            } catch {
                await MainActor.run {
                    self.pixabayErrorMessage = "Failed to download image."
                    self.isLoadingPixabay = false
                }
            }
        }
    }

    private func downloadPixabayImage(_ image: PixabayImage) async throws -> UIImage {
        guard let url = URL(string: image.largeImageURL) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let uiImage = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        return uiImage
    }

    func updateImage(_ uiImage: UIImage, sourceType: ImageSourceType, description: String) {
        currentImage = GameImage(uiImage: uiImage, sourceType: sourceType, sourceDescription: description)
        userQuery = ""
        searchResults = []
        selectedUserLabel = nil
        lastResult = nil
        aiLabel = nil
        predictionStatusMessage = "Waiting for labels (\(labelStatusMessage))"
        aiModelStatusMessage = aiLabelProvider.loadStatusDescription
        isRunningPrediction = false
        if gameMode != .labelRoulette {
            challengeLabel = nil
            challengeStatusMessage = gameMode.statusHint
        }

        // ラベルが読み込み済みなら即推論、未読込なら後で自動で推論される
        attemptPredictionIfPossible()
    }

    func updateUserQuery(_ query: String) {
        userQuery = query
        searchResults = labelRepository.searchLabels(query: query)
    }

    // クイズ終了・集計・履歴保存
    private func finalizeRouletteQuiz() {
        let total = quizTotalQuestions
        let human = quizResults.filter { $0.userMatchesGroundTruth }.count
        let ai = quizResults.filter { $0.aiMatchesGroundTruth }.count
        let humanAcc = total > 0 ? Double(human) / Double(total) : 0.0
        let aiAcc = total > 0 ? Double(ai) / Double(total) : 0.0
        let winner: Winner = human > ai ? .human : (ai > human ? .ai : .draw)
        let comment = generateComment(winner: winner, humanAccuracy: humanAcc, aiAccuracy: aiAcc)
        let summary = QuizSummary(total: total,
                                  humanCorrect: human,
                                  aiCorrect: ai,
                                  humanAccuracy: humanAcc,
                                  aiAccuracy: aiAcc,
                                  winner: winner,
                                  comment: comment,
                                  date: Date())
        quizSummary = summary
        quizIsActive = false
        challengeStatusMessage = "クイズ終了！結果をチェックしよう。"

        // 履歴保存
        let entry = QuizHistoryEntry(id: UUID(),
                                     date: summary.date,
                                     total: total,
                                     humanCorrect: human,
                                     aiCorrect: ai,
                                     humanAccuracy: humanAcc,
                                     aiAccuracy: aiAcc,
                                     winner: winner,
                                     model: selectedModel.displayName)
        quizHistory.insert(entry, at: 0)
        saveQuizHistory()
    }

    private func generateComment(winner: Winner, humanAccuracy: Double, aiAccuracy: Double) -> String {
        let h = Int((humanAccuracy * 100.0).rounded())
        let a = Int((aiAccuracy * 100.0).rounded())
        switch winner {
        case .human:
            if h >= 90 { return "人類の完全勝利！勘と経験が物理法則をねじ曲げた。" }
            if h >= 70 { return "人類優勢！AI にもたまには教えてやらないとね。" }
            return "紙一重で人類勝利。次もこの勢いで！"
        case .ai:
            if a >= 90 { return "シリコンの冷笑が聞こえる…AI の圧勝。" }
            if a >= 70 { return "AI が一枚上手。人類、次は反撃のターン！" }
            return "今回は AI に軍配。次は奇襲を仕掛けよう。"
        case .draw:
            return "互角！いい勝負。決着は次のラウンドで。"
        }
    }

    // MARK: - 履歴の永続化（UserDefaults）
    private static func loadQuizHistory() -> [QuizHistoryEntry] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: quizHistoryKey) else { return [] }
        do {
            return try JSONDecoder().decode([QuizHistoryEntry].self, from: data)
        } catch {
            print("Failed to decode quiz history: \(error)")
            return []
        }
    }

    private func saveQuizHistory() {
        let defaults = UserDefaults.standard
        do {
            let data = try JSONEncoder().encode(quizHistory)
            defaults.set(data, forKey: Self.quizHistoryKey)
        } catch {
            print("Failed to encode quiz history: \(error)")
        }
    }
}
