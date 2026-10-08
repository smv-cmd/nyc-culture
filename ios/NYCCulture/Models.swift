import Foundation

struct Feed: Codable {
    var generated: String?
    var meta: Meta?
    var sources: [Source]
}

struct Meta: Codable {
    var lastScan: String?
    var schedule: String?
    var log: [String]?
}

struct Source: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var borough: String
    var type: String
    var core: Bool
    var urls: [String]?
    var status: String?
    var itemCount: Int?
    var lastScan: String?
    var items: [Item]?

    var website: URL? { urls?.first.flatMap(URL.init(string:)) }

    var typeLabel: String {
        switch type {
        case "museum": return "Museum"
        case "library": return "Library"
        case "public": return "Park / venue"
        case "city": return "City"
        default: return type.capitalized
        }
    }

    var statusLabel: String {
        switch status {
        case "ok": return "Listing"
        case "broken_url": return "Page moved"
        case "error": return "Unreachable"
        case "no_listings": return "Nothing dated"
        default: return "Not scanned"
        }
    }
}

struct Item: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var kind: String
    var start: String?
    var end: String?
    var url: String?
    var venue: String?
    var borough: String?
    var status: String?
}

/// One listing joined with the institution it came from.
struct Entry: Identifiable, Hashable {
    let item: Item
    let source: Source
    let start: Date?
    let end: Date?

    init(item: Item, source: Source) {
        self.item = item
        self.source = source
        self.start = D.parse(item.start)
        self.end = D.parse(item.end)
    }

    var id: String { source.id + "/" + item.id }
    var isEvent: Bool { item.kind == "event" }
    var borough: String { item.borough ?? source.borough }
    var link: URL? { item.url.flatMap(URL.init(string:)) }

    /// True when the link only points at the institution's general listings page.
    var isGenericLink: Bool {
        guard let u = item.url else { return true }
        return source.urls?.contains(u) ?? false
    }

    var linkLabel: String {
        if isGenericLink { return "Listing" }
        return isEvent ? "Event page" : "Exhibition page"
    }

    var sourceLine: String {
        if let v = item.venue, !v.isEmpty, v != source.name { return source.name + " — " + v }
        return source.name
    }

    var isOnView: Bool {
        guard !isEvent else { return false }
        if let s = start, D.days(s) > 0 { return false }
        if let e = end, D.days(e) < 0 { return false }
        return true
    }

    var isOver: Bool {
        if let e = end { return D.days(e) < 0 }
        if isEvent, let s = start { return D.days(s) < 0 }
        return false
    }
}

struct AgendaRow: Identifiable {
    enum Mode: String { case event, opens, closes }
    let entry: Entry
    let mode: Mode
    let date: Date
    var id: String { entry.id + "#" + mode.rawValue }
}

struct WeekGroup: Identifiable {
    let start: Date
    let rows: [AgendaRow]
    var id: Date { start }
}

struct EntryGroup: Identifiable {
    let id: String
    let title: String
    let entries: [Entry]
}
