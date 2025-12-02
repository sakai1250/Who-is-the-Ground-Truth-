import SwiftUI
import PhotosUI

struct GameView: View {
    @State private var selectedSource: ImageSourceType = .pixabay
    @State private var selectedPhotoItem: PhotosPickerItem?

    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sourcePicker
                    Divider()
                    if selectedSource == .pixabay {
                        pixabaySection
                    } else {
                        photoLibrarySection
                    }
                    currentImageSection
                    aiLabelSection
                    statusSection
                    userAnswerSection
                    judgeSection
                    resultSection
                }
                .padding()
            }
            .navigationTitle("Who is the Ground Truth?")
            .font(.system(size: 16)) // fontsize
            
        }
    }

    private var sourcePicker: some View {
        Picker("Image Source", selection: $selectedSource) {
            Text("Pixabay").tag(ImageSourceType.pixabay)
            Text("Photos").tag(ImageSourceType.photoLibrary)
        }
        .pickerStyle(.segmented)
    }

    private var pixabaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Images from Pixabay")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Search Pixabay (e.g. dog, city, ocean)", text: $viewModel.pixabayQuery)
                    .textFieldStyle(.roundedBorder)
                Button("Search Pixabay") {
                    viewModel.searchPixabay()
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

    private var photoLibrarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                Label("Pick Photo from Library", systemImage: "photo.on.rectangle.angled")
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.updateImage(image, sourceType: .photoLibrary, description: "Photo Library")
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
                Text(viewModel.aiModelStatusMessage)
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
                if result.isExactMatch {
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

@MainActor
private struct GameView_MainActorPreview: View {
    @StateObject private var viewModel: GameViewModel

    init() {
        let repository = LabelRepository()
        let client = PixabayClient(apiKey: "YOUR_API_KEY")
        _viewModel = StateObject(wrappedValue: GameViewModel(labelRepository: repository,
                                                             pixabayClient: client))
    }

    var body: some View {
        GameView(viewModel: viewModel)
    }
}

#Preview {
    GameView_MainActorPreview()
}
