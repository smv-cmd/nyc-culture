import SwiftUI

struct ExhibitionsView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let groups = store.exhibitionGroups()
        NavigationStack {
            List {
                Section { StatusLine() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                if groups.onView.isEmpty && groups.later.isEmpty {
                    ContentUnavailableView.search(text: store.search)
                        .listRowBackground(Color.clear)
                }

                ForEach(groups.onView) { g in
                    Section {
                        ForEach(g.entries) { ItemRow(entry: $0) }
                    } header: {
                        header(g.title, count: g.entries.count)
                    }
                    .listRowBackground(Theme.panel)
                }

                if !groups.later.isEmpty {
                    Section {
                        ForEach(groups.later) { ItemRow(entry: $0, mode: .opens) }
                    } header: {
                        header("Opening later", count: groups.later.count)
                    }
                    .listRowBackground(Theme.panel)
                }
            }
            .listStyle(.insetGrouped)
            .calendarChrome("Exhibitions")
        }
    }

    private func header(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.headline, design: .serif)).foregroundStyle(Theme.fg)
            Spacer()
            Text("\(count)").font(.caption.monospaced()).foregroundStyle(Theme.muted)
        }
        .textCase(nil)
    }
}
