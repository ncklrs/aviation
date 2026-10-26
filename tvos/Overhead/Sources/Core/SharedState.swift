import Foundation

/// Small snapshot the app shares with the optional Top Shelf extension through an App Group.
/// The group id comes from Info.plist key `OverheadAppGroup` (set from project.yml); if the group isn't
/// provisioned, writes silently do nothing and Top Shelf shows its static fallback.
enum SharedState {
    static var groupID: String? { Bundle.main.object(forInfoDictionaryKey: "OverheadAppGroup") as? String }
    static var defaults: UserDefaults? { groupID.flatMap { UserDefaults(suiteName: $0) } }
    static var posterURL: URL? {
        #if os(Linux)
        return nil
        #else
        return groupID.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }?.appendingPathComponent("topshelf-poster.png")
        #endif
    }
    static func write(count: Int, nearest: String?, date: Date = Date()) {
        guard let d = defaults else { return }
        d.set(count, forKey: "count"); d.set(nearest, forKey: "nearest"); d.set(date.timeIntervalSince1970, forKey: "at")
    }
    static func read() -> (count: Int, nearest: String?, at: Date?) {
        guard let d = defaults else { return (0, nil, nil) }
        let t = d.double(forKey: "at")
        return (d.integer(forKey: "count"), d.string(forKey: "nearest"), t > 0 ? Date(timeIntervalSince1970: t) : nil)
    }
}
