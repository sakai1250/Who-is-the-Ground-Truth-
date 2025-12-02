import SwiftUI

struct PixabayModeView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                modelPicker

                Divider()

                pixabaySection
                currentImageSection
                aiLabelSection
                statusSection
            }
            .padding()
            .font(.system(size: 16))
        }
        .navigationTitle("Stock Safari")
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

    private var pixabaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pixabay 検索")
                .font(.headline)
            HStack(spacing: 12) {
                TextField("Search Pixabay (e.g. dog, city, ocean)", text: $viewModel.pixabayQuery)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { viewModel.searchPixabay() }
                Button {
                    viewModel.searchPixabay()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
            }

            if viewModel.isLoadingPixabay {
                ProgressView().padding(.vertical, 4)
            }

            if let error = viewModel.pixabayErrorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            PixabayResultsView(items: viewModel.pixabayResults) { image in
                viewModel.selectPixabayImage(image)
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
            Text("AI Prediction")
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

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Status")
                .font(.headline)
            statusRow(title: "Mode", message: viewModel.gameMode.statusHint)
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
