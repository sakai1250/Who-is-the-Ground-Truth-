import Foundation
import UIKit

enum ImageSourceType {
    case pixabay
    case photoLibrary
}

struct GameImage {
    let uiImage: UIImage
    let sourceType: ImageSourceType
    let sourceDescription: String  // e.g. "Pixabay: <user> / <id>" or "Photo Library"
}
