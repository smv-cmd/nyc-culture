import SwiftUI
import SafariServices

// MARK: In-app browser

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(Theme.accent)
        vc.preferredBarTintColor = UIColor(Theme.bg)
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

/// Lets a row open a link without knowing who presents the browser.
private struct OpenWebKey: EnvironmentKey {
    static let defaultValue: @MainActor (URL) -> Void = { _ in }
}

extension EnvironmentValues {
    var openWeb: @MainActor (URL) -> Void {
        get { self[OpenWebKey.self] }
        set { self[OpenWebKey.self] = newValue }
    }
}

// MARK: Listing row

struct ItemRow: View {
    let entry: Entry
    var mode: AgendaRow.Mode? = nil
    var showSource = true
    @Environment(\.openWeb) private var openWeb

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Theme.borough(entry.borough))
                .frame(width: 3)
            dateBadge
                .frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.item.title)
                        .font(.headline)
                        .foregroundStyle(Theme.fg)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let pill { PillView(text: pill.0, color: pill.1) }
                }
                if showSource {
                    Text(entry.sourceLine)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                if let when = whenLine {
                    Text(when).font(.caption).foregroundStyle(Theme.muted)
                }
                if entry.link != nil {
                    Label(entry.linkLabel, systemImage: "arrow.up.right")
                        .labelStyle(TrailingIconLabel())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { if let u = entry.link { openWeb(u) } }
        .contextMenu {
            if let u = entry.link {
                Button { openWeb(u) } label: { Label("Open " + entry.linkLabel.lowercased(), systemImage: "safari") }
                ShareLink(item: u) { Label("Share", systemImage: "square.and.arrow.up") }
            }
            if let site = entry.source.website {
                Button { openWeb(site) } label: { Label(entry.source.name, systemImage: "building.columns") }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(entry.link != nil ? "Opens the \(entry.linkLabel.lowercased())" : "")
    }

    private var pill: (String, Color)? {
        switch mode {
        case .event: return ("Event", Theme.accent)
        case .opens: return ("Opens", Theme.ok)
        case .closes: return ("Last day", Theme.warn)
        case nil: return entry.isEvent ? ("Event", Theme.accent) : nil
        }
    }

    @ViewBuilder private var dateBadge: some View {
        switch mode {
        case .opens:
            badge(top: "opens", main: entry.start.map(D.short) ?? "—")
        case .closes:
            badge(top: "last day", main: entry.end.map(D.short) ?? "—")
        case .event, nil:
            if entry.isEvent {
                if let s = entry.start, let e = entry.end, D.days(s) < 0 {
                    badge(top: "until", main: D.short(e))
                } else if let d = entry.start ?? entry.end {
                    badge(top: D.weekday.string(from: d), main: D.short(d))
                } else {
                    badge(top: "", main: "—")
                }
            } else if let e = entry.end {
                badge(top: "until", main: D.short(e))
            } else {
                badge(top: "", main: "Ongoing")
            }
        }
    }

    private func badge(top: String, main: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(top).font(.caption2.monospaced()).foregroundStyle(Theme.muted)
            Text(main).font(.subheadline.monospaced().weight(.medium)).foregroundStyle(Theme.fg)
                .minimumScaleFactor(0.8).lineLimit(1)
        }
    }

    private var whenLine: String? {
        if entry.isEvent {
            if let s = entry.start, let e = entry.end, s != e { return "through " + D.short(e) }
            return nil
        }
        var parts: [String] = []
        if let s = entry.start, D.days(s) > 0 { parts.append("opens " + D.short(s)) }
        if let e = entry.end { parts.append("through " + D.full(e)) }
        parts.append(entry.borough)
        return parts.joined(separator: " · ")
    }
}

struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.title; configuration.icon }
    }
}

struct PillView: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: 1))
            .fixedSize()
    }
}

// MARK: Shared toolbar, search and filters

struct CalendarChrome: ViewModifier {
    @Environment(Store.self) private var store
    let title: String

    func body(content: Content) -> some View {
        @Bindable var store = store
        return content
            .navigationTitle(title)
            .searchable(text: $store.search, prompt: "Titles or institutions")
            .refreshable { await store.refresh() }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ScopeMenu() }
                ToolbarItem(placement: .topBarTrailing) { FilterMenu() }
            }
    }
}

extension View {
    func calendarChrome(_ title: String) -> some View { modifier(CalendarChrome(title: title)) }
}

struct ScopeMenu: View {
    @Environment(Store.self) private var store
    var body: some View {
        Menu {
            Picker("Calendar", selection: Binding(get: { store.scope }, set: { store.setScope($0) })) {
                ForEach(Scope.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(store.scope.short).font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .foregroundStyle(Theme.accent)
        }
        .accessibilityLabel("Calendar: \(store.scope.label)")
    }
}

struct FilterMenu: View {
    @Environment(Store.self) private var store
    private let types: [(String, String)] = [("museum", "Museums"), ("library", "Libraries"),
                                             ("public", "Parks & venues"), ("city", "City")]
    var body: some View {
        Menu {
            Section("Borough") {
                ForEach(Theme.boroughs, id: \.self) { b in
                    Toggle(b, isOn: Binding(
                        get: { store.boroughs.contains(b) },
                        set: { on in if on { store.boroughs.insert(b) } else { store.boroughs.remove(b) } }))
                }
            }
            Section("Type") {
                ForEach(types, id: \.0) { t in
                    Toggle(t.1, isOn: Binding(
                        get: { store.types.contains(t.0) },
                        set: { on in if on { store.types.insert(t.0) } else { store.types.remove(t.0) } }))
                }
            }
            if store.filtersActive {
                Button("Clear filters", role: .destructive) { store.boroughs = []; store.types = [] }
            }
        } label: {
            Image(systemName: store.filtersActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(store.filtersActive ? "Filters, active" : "Filters")
    }
}

/// Small status line shown at the top of lists.
struct StatusLine: View {
    @Environment(Store.self) private var store
    var body: some View {
        HStack(spacing: 8) {
            if store.offline {
                Label("Offline · saved data", systemImage: "wifi.slash").foregroundStyle(Theme.warn)
            } else if let t = store.lastScanText {
                Text(t)
            }
            if store.filtersActive {
                Text("· filtered").foregroundStyle(Theme.accent)
            }
            Spacer()
            if store.loading { ProgressView().controlSize(.mini) }
        }
        .font(.caption)
        .foregroundStyle(Theme.muted)
    }
}
