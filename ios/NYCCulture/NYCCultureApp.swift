import SwiftUI

@main
struct NYCCultureApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.tab) {
            AgendaView()
                .tabItem { Label("Agenda", systemImage: "calendar") }
                .tag(Tab.agenda)
            ExhibitionsView()
                .tabItem { Label("Exhibitions", systemImage: "photo.artframe") }
                .tag(Tab.exhibitions)
            MapTabView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(Tab.map)
            InstitutionsView()
                .tabItem { Label("Institutions", systemImage: "building.columns") }
                .tag(Tab.institutions)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .environment(\.openWeb) { store.open($0) }
        .sheet(item: $store.web) { SafariView(url: $0.url).ignoresSafeArea() }
        .task { await store.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refreshIfStale() } }
        }
    }
}
