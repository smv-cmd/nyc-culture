import SwiftUI

struct AgendaView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let rows = store.agenda().filter { store.agendaFocus == nil || $0.mode == store.agendaFocus }
        let weeks = store.weeks(rows)
        NavigationStack {
            List {
                Section {
                    StatsGrid()
                    StatusLine()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                if let focus = store.agendaFocus {
                    Section {
                        Button {
                            store.agendaFocus = nil
                        } label: {
                            Label("Showing \(focusName(focus)) only · Show everything", systemImage: "xmark.circle")
                                .font(.subheadline)
                        }
                    }
                    .listRowBackground(Theme.panel)
                }

                if weeks.isEmpty {
                    ContentUnavailableView("Nothing dated",
                                           systemImage: "calendar.badge.exclamationmark",
                                           description: Text("Nothing in the next 90 days matches these filters."))
                        .listRowBackground(Color.clear)
                }

                ForEach(weeks) { week in
                    Section {
                        ForEach(week.rows) { r in ItemRow(entry: r.entry, mode: r.mode) }
                    } header: {
                        WeekHeader(start: week.start)
                    }
                    .listRowBackground(Theme.panel)
                }
            }
            .listStyle(.insetGrouped)
            .calendarChrome("Agenda")
        }
    }

    private func focusName(_ m: AgendaRow.Mode) -> String {
        switch m {
        case .event: return "events"
        case .opens: return "openings"
        case .closes: return "closings"
        }
    }
}

struct WeekHeader: View {
    let start: Date
    var body: some View {
        let diff = (D.cal.dateComponents([.day], from: D.weekStart(D.today), to: start).day ?? 0) / 7
        let end = D.cal.date(byAdding: .day, value: 6, to: start) ?? start
        HStack(alignment: .firstTextBaseline) {
            Text(diff == 0 ? "This week" : diff == 1 ? "Next week" : "Week of " + D.longMonthDay.string(from: start))
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Theme.fg)
                .textCase(nil)
            Spacer()
            Text(D.short(start) + " – " + D.short(end))
                .font(.caption.monospaced())
                .foregroundStyle(Theme.muted)
                .textCase(nil)
        }
    }
}

struct StatsGrid: View {
    @Environment(Store.self) private var store

    var body: some View {
        let s = store.stats
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            tile(s.onView, "Exhibitions on view", selected: false) { store.tab = .exhibitions }
            tile(s.opening, "Opening in 30 days", selected: store.agendaFocus == .opens) { toggle(.opens) }
            tile(s.closing, "Closing in 30 days", selected: store.agendaFocus == .closes) { toggle(.closes) }
            tile(s.events, "Events in 30 days", selected: store.agendaFocus == .event) { toggle(.event) }
        }
    }

    private func toggle(_ m: AgendaRow.Mode) {
        store.agendaFocus = store.agendaFocus == m ? nil : m
    }

    private func tile(_ n: Int, _ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(n)").font(.system(size: 26, weight: .medium, design: .monospaced)).foregroundStyle(Theme.fg)
                Text(label).font(.caption).foregroundStyle(Theme.muted).lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Theme.accent : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(n) \(label)")
    }
}
