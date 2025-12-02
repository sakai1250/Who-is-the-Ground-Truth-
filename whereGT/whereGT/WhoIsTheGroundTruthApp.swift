import SwiftUI

@main
struct WhoIsTheGroundTruthApp: App {
    @StateObject private var labelRepository: LabelRepository
    @StateObject private var viewModel: GameViewModel

    @MainActor
    init() {
        let repository = LabelRepository()
        let apiKey = EnvLoader.shared.value(for: "PIXABAY_API_KEY") ?? "YOUR_API_KEY"
        let pixabayClient = PixabayClient(apiKey: apiKey)
        _labelRepository = StateObject(wrappedValue: repository)
        _viewModel = StateObject(wrappedValue: GameViewModel(labelRepository: repository,
                                                             pixabayClient: pixabayClient))
    }

    var body: some Scene {
        WindowGroup {
            GameView(viewModel: viewModel)
        }
    }
}
