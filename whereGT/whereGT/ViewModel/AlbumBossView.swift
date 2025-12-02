import SwiftUI
import PhotosUI

struct AlbumBossView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                modelPicker

                Divider()

                photoLibrarySection
                currentImageSection
                aiLabelSection
                statusSection

                userAnswerSection
                judgeSection
                resultSection
            }
            .padding()
            .font(.system(size: 16))
        }
        .navigationTitle("Album Boss")
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

    private var photoLibrarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("アルバムの刺客")
                .font(.headline)
            Text("カメラロールから刺客を選んで AI に叩きつけるモード。")
                .font(.caption)
                .foregroundStyle(.secondary)
            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                Label("Pick Photo from Library", systemImage: "photo.on.rectangle.angled")
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.updateImage(image, sourceType: .photoLibrary, description: "Photo Library (Album Boss)")
                        }
                    }
                }
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

    private var userAnswerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Answer")
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
        }
    }

    private var judgeSection: some View {
        Button {
            viewModel.judge()
        } label: {
            Text("Judge")
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
            Text("Status")
                .font(.headline)
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
