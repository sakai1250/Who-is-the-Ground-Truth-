import Foundation

struct LabelItem: Identifiable, Hashable {
    let id: String            // synset ID
    let primaryName: String   // first name after ID
    let alias: [String]       // other names
}
