import SwiftUI

struct StartView: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.35), .purple.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text("Where's the Ground Truth?")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("AI と人類、どちらが真実にたどり着く？3つのモードで腕試し。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                Button(action: onStart) {
                    Label("ゲームを始める", systemImage: "gamecontroller.fill")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 22)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    StartView(onStart: {})
}
