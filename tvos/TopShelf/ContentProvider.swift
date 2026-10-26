import TVServices

/// Optional Top Shelf: the latest poster (rendered by the app into the App Group) and a live count.
final class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent() async -> TVTopShelfContent? {
        let snap = SharedState.read()
        let item = TVTopShelfSectionedItem(identifier: "overhead")
        if let at = snap.at, Date().timeIntervalSince(at) < 600 {
            item.title = "\(snap.count) aircraft overhead" + (snap.nearest.map { " · nearest \($0)" } ?? "")
        } else {
            item.title = "Overhead · open for the live sky"
        }
        if let u = SharedState.posterURL, FileManager.default.fileExists(atPath: u.path) {
            item.setImageURL(u, for: [.screenScale1x, .screenScale2x])
        }
        item.imageShape = .poster
        item.playAction = nil
        item.displayAction = URL(string: "overhead://live").map { TVTopShelfAction(url: $0) }
        let section = TVTopShelfItemCollection(items: [item]); section.title = "Overhead"
        return TVTopShelfSectionedContent(sections: [section])
    }
}
