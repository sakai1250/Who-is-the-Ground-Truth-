import SwiftUI

struct ModeSelectionView: View {
    let onSelect: (GameMode) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("モードを選択")
                    .font(.title2.weight(.bold))
                    .padding(.bottom, 4)
                Text("遊び方に合わせて3つのバトルスタイルから選んでください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(GameMode.allCases) { mode in
                    Button {
                        onSelect(mode)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(mode.displayName)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(mode.description)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(mode.statusHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Mode Select")
    }
}

#Preview {
    ModeSelectionView { _ in }
}
