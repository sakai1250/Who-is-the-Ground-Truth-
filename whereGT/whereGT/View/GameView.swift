import SwiftUI

private enum AppTab: Hashable {
    case pixabay
    case album
    case roulette
}

struct GameView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var selectedTab: AppTab = .pixabay

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PixabayModeView(viewModel: viewModel)
            }
            .tabItem {
                Label("Pixabay", systemImage: "photo.on.rectangle")
            }
            .tag(AppTab.pixabay)

            NavigationStack {
                AlbumBossView(viewModel: viewModel)
            }
            .tabItem {
                Label("Album", systemImage: "photo.on.rectangle.angled")
            }
            .tag(AppTab.album)

            NavigationStack {
                LabelRouletteView(viewModel: viewModel)
            }
            .tabItem {
                Label("Roulette", systemImage: "die.face.5")
            }
            .tag(AppTab.roulette)
        }
        .onAppear {
            // 初期タブに応じてモードを合わせる
            applyMode(for: selectedTab)
        }
        .onChange(of: selectedTab) { _, newValue in
            applyMode(for: newValue)
        }
    }

    private func applyMode(for tab: AppTab) {
        switch tab {
        case .pixabay:
            if viewModel.gameMode != .pixabaySearch { viewModel.gameMode = .pixabaySearch }
        case .album:
            if viewModel.gameMode != .albumBoss { viewModel.gameMode = .albumBoss }
        case .roulette:
            if viewModel.gameMode != .labelRoulette { viewModel.gameMode = .labelRoulette }
        }
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
