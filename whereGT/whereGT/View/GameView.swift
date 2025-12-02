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
        ZStack {
            AngularGradient(gradient: Gradient(colors: [.teal.opacity(0.9),
                                                        .blue.opacity(0.85),
                                                        .indigo.opacity(0.9),
                                                        .cyan.opacity(0.85),
                                                        .teal.opacity(0.9)]),
                            center: .center)
                .ignoresSafeArea()
            Circle()
                .strokeBorder(.white.opacity(0.18), lineWidth: 12)
                .blur(radius: 10)
                .scaleEffect(1.6)
                .offset(x: -140, y: -220)
            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(LinearGradient(colors: [.black.opacity(0.28), .clear, .white.opacity(0.2)],
                                     startPoint: .top, endPoint: .bottom))
                .rotationEffect(.degrees(18))
                .scaleEffect(1.4)
                .offset(x: 90, y: 160)
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Who is the GT???")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .shadow(color: .white.opacity(0.6), radius: 18, y: 6)
                    Text("最近の AI は凄いらしい。ほんとに？\n自分の指で決闘して確かめる深夜の儀式。")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 14) {
                    Text("ルール: 弱音禁止。決着はスクリーンが知っている。")
                        .foregroundStyle(.white.opacity(0.95))
                    Text("負けたものには二言なし、指先で勝ち取れ。")
                        .foregroundStyle(.white.opacity(0.78))
                }
                Button(action: onStart) {
                    Label("決戦開始（言い訳禁止）", systemImage: "arrow.right.to.line.alt")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [.teal, .white, .yellow],
                                           startPoint: .leading, endPoint: .trailing)
                                .opacity(0.9)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.8), lineWidth: 1.5)
                        )
                }
                .shadow(color: .pink.opacity(0.5), radius: 16, y: 6)
                .padding(.horizontal)
                Text("※ AI に負けても、後悔と返金は受け付けません。")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal)
            .padding(.vertical, 48)
            .background(Color.black.opacity(0.38))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        }
        .navigationTitle("Start?!!")
    }
}

private struct ModeSelectionView: View {
    let onSelect: (GameMode) -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [.teal.opacity(0.8), .blue.opacity(0.82), .indigo.opacity(0.86)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Color.black.opacity(0.18)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Text("どの決戦舞台で AI に挑む？")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.top, 10)
                List {
                    ForEach(GameMode.allCases) { mode in
                        Button {
                            onSelect(mode)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(LinearGradient(colors: [.indigo.opacity(0.88),
                                                                  .blue.opacity(0.8),
                                                                  .teal.opacity(0.7)],
                                                         startPoint: .topLeading,
                                                         endPoint: .bottomTrailing))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(.white.opacity(0.4), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(mode.displayName.uppercased())
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text(mode.description + "｜言い訳は後で禁止。")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.82))
                                    }
                                    Spacer()
                                    Image(systemName: "eyes.inverse")
                                        .foregroundStyle(.yellow.opacity(0.9))
                                        .rotationEffect(.degrees(-6))
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 12)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Select a Weird Mode")
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
