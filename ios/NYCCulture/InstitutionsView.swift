import SwiftUI

struct InstitutionsView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let counts = store.countsBySource()
        let q = store.search.trimmingCharacters(in: .whitespaces).lowercased()
        let list = store.sources.filter { s in
            store.sourceVisible(s) && (q.isEmpty || s.name.lowercased().contains(q)
                                       || (counts[s.id] ?? 0) > 0)
        }
        let groups = Dictionary(grouping: list, by: \.borough)
        let order = ["Manhattan", "Brooklyn", "Queens", "Citywide"]
        NavigationStack {
            List {
                Section {
                    StatusLine()
                    Text("\(list.count) institutions · \(list.filter { $0.status == "ok" }.count) with listings")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                ForEach(order.filter { groups[$0] != nil }, id: \.self) { b in
                    Section {
                        ForEach((groups[b] ?? []).sorted { $0.name < $1.name }) { s in
                            NavigationLink(value: s) { InstitutionRow(source: s, count: counts[s.id] ?? 0) }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Circle().fill(Theme.borough(b)).frame(width: 8, height: 8)
                            Text(b).font(.system(.headline, design: .serif)).foregroundStyle(Theme.fg)
                        }
                        .textCase(nil)
                    }
                    .listRowBackground(Theme.panel)
                }
            }
            .listStyle(.insetGrouped)
            .navigationDestination(for: Source.self) { InstitutionDetail(source: $0) }
            .calendarChrome("Institutions")
        }
    }
}

struct InstitutionRow: View {
    let source: Source
    let count: Int
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name).font(.body).foregroundStyle(Theme.fg)
                Text(source.typeLabel + (source.core ? " · Core 30" : ""))
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)").font(.subheadline.monospaced()).foregroundStyle(Theme.fg)
                Text(source.statusLabel).font(.caption2).foregroundStyle(Theme.status(source.status))
            }
        }
    }
}

struct InstitutionDetail: View {
    @Environment(Store.self) private var store
    @Environment(\.openWeb) private var openWeb
    let source: Source

    var body: some View {
        let list = store.entries(for: source)
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.borough(source.borough)).frame(width: 8, height: 8)
                        Text(source.borough + " · " + source.typeLabel + (source.core ? " · Core 30" : ""))
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    Text(source.name).font(.display).foregroundStyle(Theme.fg)
                    Text(source.statusLabel + (source.lastScan.map { " · scanned " + $0 } ?? ""))
                        .font(.caption).foregroundStyle(Theme.status(source.status))
                }
                .padding(.vertical, 4)
                if let site = source.website {
                    Button { openWeb(site) } label: {
                        Label("Visit website", systemImage: "safari").foregroundStyle(Theme.accent)
                    }
                }
            }
            .listRowBackground(Theme.panel)

            Section {
                if list.isEmpty {
                    Text(source.status == "ok"
                         ? "Nothing here matches the current filters."
                         : "This institution's page had no dated listings at the last scan.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                ForEach(list) { e in
                    ItemRow(entry: e, mode: e.isEvent ? .event : nil, showSource: false)
                }
            } header: {
                Text("\(list.count) listing\(list.count == 1 ? "" : "s")").textCase(nil)
            }
            .listRowBackground(Theme.panel)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle(source.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
