import SwiftUI

private enum AppRoute: Hashable {
    case modeSelection
    case mode(GameMode)
}

struct GameView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            StartView {
                // スタート画面からモード選択へ
                path.append(.modeSelection)
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .modeSelection:
                    ModeSelectionView { selected in
                        // モードをセットして各モード画面へプッシュ
                        if viewModel.gameMode != selected {
                            viewModel.gameMode = selected
                        }
                        path.append(.mode(selected))
                    }
                case .mode(let mode):
                    // 副作用は .onAppear へ移動（ViewBuilder が Void を受けないようにする）
                    modeView(for: mode)
                        .onAppear {
                            if viewModel.gameMode != mode {
                                viewModel.gameMode = mode
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func modeView(for mode: GameMode) -> some View {
        switch mode {
        case .pixabaySearch:
            PixabayModeView(viewModel: viewModel)
                .navigationTitle("Stock Safari")
        case .albumBoss:
            AlbumBossView(viewModel: viewModel)
                .navigationTitle("Album Boss")
        case .labelRoulette:
            LabelRouletteView(viewModel: viewModel)
                .navigationTitle("Label Roulette")
        }
    }
}

private struct StartView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Text("WhereGT")
                    .font(.largeTitle.weight(.bold))
                Text("画像で AI と勝負しよう")
                    .foregroundStyle(.secondary)
            }
            Button(action: onStart) {
                Label("Start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            Spacer()
        }
        .padding()
        .navigationTitle("Start")
    }
}

private struct ModeSelectionView: View {
    let onSelect: (GameMode) -> Void

    var body: some View {
        List {
            ForEach(GameMode.allCases) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.displayName)
                                .font(.headline)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Select Mode")
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
