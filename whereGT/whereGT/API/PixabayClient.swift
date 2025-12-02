import Foundation

struct PixabayImage: Identifiable, Decodable {
    let id: Int
    let previewURL: String
    let largeImageURL: String
    let user: String
}

struct PixabayResponse: Decodable {
    let total: Int
    let totalHits: Int
    let hits: [PixabayImage]
}

/// Lightweight Pixabay search client.
final class PixabayClient {
    let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func searchImages(query: String) async throws -> [PixabayImage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://pixabay.com/api/")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "image_type", value: "photo")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(PixabayResponse.self, from: data)
        return decoded.hits
    }
}
