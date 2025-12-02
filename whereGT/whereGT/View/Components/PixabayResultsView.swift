import SwiftUI

struct PixabayResultsView: View {
    let items: [PixabayImage]
    let onSelect: (PixabayImage) -> Void

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items) { item in
                Button {
                    onSelect(item)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        AsyncImage(url: URL(string: item.previewURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 80)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                                    .clipped()
                                    .cornerRadius(8)
                            case .failure:
                                Color.gray.opacity(0.2)
                                    .overlay(Image(systemName: "exclamationmark.triangle"))
                                    .frame(maxWidth: .infinity, minHeight: 120)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        Text("By \(item.user)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("#\(item.id)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    PixabayResultsView(items: [], onSelect: { _ in })
}
