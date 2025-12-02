import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    @Published var currentImage: GameImage?
    @Published var aiLabel: LabelItem?
    @Published var labelStatusMessage: String = "Labels not loaded"
    @Published var aiModelStatusMessage: String
    @Published var predictionStatusMessage: String = "Waiting for image"
    @Published var isRunningPrediction: Bool = false

    @Published var userQuery: String = ""
    @Published var searchResults: [LabelItem] = []
    @Published var selectedUserLabel: LabelItem?

    @Published var lastResult: GameResult?

    @Published var pixabayQuery: String = ""
    @Published var pixabayResults: [PixabayImage] = []
    @Published var isLoadingPixabay: Bool = false
    @Published var pixabayErrorMessage: String?

    private let labelRepository: LabelRepository
    private let aiLabelProvider: AILabelProvider
    private let pixabayClient: PixabayClient

    private var cancellables = Set<AnyCancellable>()

    init(labelRepository: LabelRepository,
         aiLabelProvider: AILabelProvider = CoreMLImageNet21KLabelProvider(),
         pixabayClient: PixabayClient) {
        self.labelRepository = labelRepository
        self.aiLabelProvider = aiLabelProvider
        self.pixabayClient = pixabayClient
        self.aiModelStatusMessage = aiLabelProvider.loadStatusDescription

        // ラベル読み込みを開始し、進捗も監視
        labelRepository.$loadStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.labelStatusMessage = Self.labelStatusText(from: status)
            }
            .store(in: &cancellables)

        labelRepository.loadLabels()

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

    func selectPixabayImage(_ image: PixabayImage) {
        guard let url = URL(string: image.largeImageURL) else { return }
        isLoadingPixabay = true
        pixabayErrorMessage = nil

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let uiImage = UIImage(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                await MainActor.run {
                    let description = "Pixabay: \(image.user) / \(image.id)"
                    self.updateImage(uiImage, sourceType: .pixabay, description: description)
                    self.isLoadingPixabay = false
                }
            } catch {
                await MainActor.run {
                    self.pixabayErrorMessage = "Failed to download image."
                    self.isLoadingPixabay = false
                }
            }
        }
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

        // ラベルが読み込み済みなら即推論、未読込なら後で自動で推論される
        attemptPredictionIfPossible()
    }

    func updateUserQuery(_ query: String) {
        userQuery = query
        searchResults = labelRepository.searchLabels(query: query)
    }

    func judge() {
        guard let aiLabel, let selectedUserLabel else { return }
        let result = GameResult(aiLabel: aiLabel,
                                userLabel: selectedUserLabel,
                                isExactMatch: aiLabel.id == selectedUserLabel.id,
                                timestamp: Date())
        lastResult = result
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
}
