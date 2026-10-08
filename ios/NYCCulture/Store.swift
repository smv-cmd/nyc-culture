import SwiftUI
import Observation

enum Scope: String, CaseIterable, Identifiable {
    case all, core
    var id: String { rawValue }
    var label: String { self == .all ? "All institutions" : "Core 30" }
    var short: String { self == .all ? "All" : "Core 30" }
}

enum Tab: Hashable { case agenda, exhibitions, map, institutions }

struct WebLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

@MainActor
@Observable
final class Store {
    static let feedURL = URL(string: "https://smv-cmd.github.io/nyc-culture/data.json")!

    var feed: Feed?
    var loading = false
    var offline = false
    var lastFetch: Date?

    private(set) var scope: Scope
    var boroughs: Set<String> = []
    var types: Set<String> = []
    var search = ""
    var tab: Tab = .agenda
    var agendaFocus: AgendaRow.Mode?
    var web: WebLink?

    init() {
        scope = Scope(rawValue: UserDefaults.standard.string(forKey: "scope") ?? "") ?? .all
        loadSaved()
    }

    func setScope(_ s: Scope) {
        scope = s
        UserDefaults.standard.set(s.rawValue, forKey: "scope")
    }

    func open(_ url: URL) { web = WebLink(url: url) }

    // MARK: Loading

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("feed.json")
    }

    private func decode(_ data: Data) -> Feed? { try? JSONDecoder().decode(Feed.self, from: data) }

    /// Last downloaded copy, or the copy bundled with the app on first launch.
    private func loadSaved() {
        if let d = try? Data(contentsOf: cacheURL), let f = decode(d) {
            feed = f
        } else if let u = Bundle.main.url(forResource: "data", withExtension: "json"),
                  let d = try? Data(contentsOf: u), let f = decode(d) {
            feed = f
        }
    }

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            var req = URLRequest(url: Self.feedURL)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 20
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200, let f = decode(data) else {
                throw URLError(.badServerResponse)
            }
            feed = f
            offline = false
            lastFetch = Date()
            try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
        } catch {
            offline = true
        }
    }

    func refreshIfStale() async {
        if let last = lastFetch, Date().timeIntervalSince(last) < 3600 { return }
        await refresh()
    }

    // MARK: Derived data

    var allSources: [Source] { feed?.sources ?? [] }
    var sources: [Source] { allSources.filter { scope == .all || $0.core } }

    var lastScanText: String? {
        guard let s = feed?.meta?.lastScan, let d = D.parse(s) else { return nil }
        return "Last scan " + D.short(d)
    }

    var filtersActive: Bool { !boroughs.isEmpty || !types.isEmpty }

    private var activeEntries: [Entry] {
        sources.flatMap { s in
            (s.items ?? []).filter { $0.status != "closed" }.map { Entry(item: $0, source: s) }
        }
    }

    func matches(_ e: Entry) -> Bool {
        if !boroughs.isEmpty && !boroughs.contains(e.borough) { return false }
        if !types.isEmpty && !types.contains(e.source.type) { return false }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            let hay = (e.item.title + " " + e.source.name + " " + (e.item.venue ?? "")).lowercased()
            if !hay.contains(q) { return false }
        }
        return true
    }

    var entries: [Entry] { activeEntries.filter(matches) }

    func sourceVisible(_ s: Source) -> Bool {
        (boroughs.isEmpty || boroughs.contains(s.borough) || s.borough == "Citywide")
            && (types.isEmpty || types.contains(s.type))
    }

    func entries(for source: Source) -> [Entry] {
        entries.filter { $0.source.id == source.id && !$0.isOver }
            .sorted { sortKey($0) < sortKey($1) }
    }

    private func sortKey(_ e: Entry) -> Date {
        (e.isEvent ? (e.start ?? e.end) : e.end) ?? .distantFuture
    }

    func countsBySource() -> [String: Int] {
        Dictionary(grouping: entries.filter { !$0.isOver }, by: { $0.source.id }).mapValues(\.count)
    }

    // MARK: Agenda

    func agenda(horizon: Int = 90) -> [AgendaRow] {
        var rows: [AgendaRow] = []
        let today = D.today
        for e in entries {
            if e.isEvent {
                let ds = e.start.map(D.days)
                let de = e.end.map(D.days)
                if let s = ds, s >= 0, s <= horizon, let start = e.start {
                    rows.append(AgendaRow(entry: e, mode: .event, date: start))
                } else if let s = ds, s < 0, let en = de, en >= 0 {
                    rows.append(AgendaRow(entry: e, mode: .event, date: today))
                } else if ds == nil, let en = de, en >= 0, en <= horizon, let end = e.end {
                    rows.append(AgendaRow(entry: e, mode: .event, date: end))
                }
            } else {
                if let s = e.start {
                    let d = D.days(s)
                    if d > 0 && d <= horizon { rows.append(AgendaRow(entry: e, mode: .opens, date: s)) }
                }
                if let en = e.end {
                    let d = D.days(en)
                    if d >= 0 && d <= horizon { rows.append(AgendaRow(entry: e, mode: .closes, date: en)) }
                }
            }
        }
        return rows.sorted { ($0.date, $0.entry.item.title) < ($1.date, $1.entry.item.title) }
    }

    func weeks(_ rows: [AgendaRow]) -> [WeekGroup] {
        let grouped = Dictionary(grouping: rows, by: { D.weekStart($0.date) })
        return grouped.keys.sorted().map { WeekGroup(start: $0, rows: grouped[$0] ?? []) }
    }

    struct Stats { var onView = 0, opening = 0, closing = 0, events = 0 }

    var stats: Stats {
        var s = Stats()
        for e in entries {
            if e.isEvent {
                let startsSoon = e.start.map { D.days($0) >= 0 && D.days($0) <= 30 } ?? false
                let running = (e.start.map { D.days($0) < 0 } ?? true) && (e.end.map { D.days($0) >= 0 } ?? false)
                if startsSoon || running { s.events += 1 }
            } else {
                if e.isOnView { s.onView += 1 }
                if let st = e.start, D.days(st) > 0, D.days(st) <= 30 { s.opening += 1 }
                if let en = e.end, D.days(en) >= 0, D.days(en) <= 30 { s.closing += 1 }
            }
        }
        return s
    }

    // MARK: Exhibitions

    func exhibitionGroups() -> (onView: [EntryGroup], later: [Entry]) {
        let ex = entries.filter { !$0.isEvent && !$0.isOver }
        let now = ex.filter(\.isOnView)
        let later = ex.filter { !$0.isOnView }.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
        let byMonth = Dictionary(grouping: now) { e -> String in
            guard let end = e.end else { return "9999" }
            return String(D.iso.string(from: end).prefix(7))
        }
        let groups = byMonth.keys.sorted().map { key -> EntryGroup in
            let list = (byMonth[key] ?? []).sorted {
                ($0.end ?? .distantFuture, $0.item.title) < ($1.end ?? .distantFuture, $1.item.title)
            }
            let title: String
            if key == "9999" {
                title = "Ongoing, no closing date"
            } else if let d = D.parse(key + "-01") {
                title = "Closing in " + D.monthYear.string(from: d)
            } else {
                title = key
            }
            return EntryGroup(id: key, title: title, entries: list)
        }
        return (groups, later)
    }
}
