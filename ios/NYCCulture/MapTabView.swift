import SwiftUI
import MapKit
import CoreLocation

struct MapTabView: View {
    @Environment(Store.self) private var store
    @State private var position: MapCameraPosition = .region(Self.regions["All"]!)
    @State private var selected: Source?
    @State private var locationManager = CLLocationManager()

    static let regions: [String: MKCoordinateRegion] = [
        "All": MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.712, longitude: -73.93),
                                  span: MKCoordinateSpan(latitudeDelta: 0.21, longitudeDelta: 0.19)),
        "Manhattan": MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.765, longitude: -73.975),
                                        span: MKCoordinateSpan(latitudeDelta: 0.13, longitudeDelta: 0.09)),
        "Brooklyn": MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.672, longitude: -73.965),
                                       span: MKCoordinateSpan(latitudeDelta: 0.11, longitudeDelta: 0.10)),
        "Queens": MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.735, longitude: -73.86),
                                     span: MKCoordinateSpan(latitudeDelta: 0.13, longitudeDelta: 0.16)),
    ]

    var body: some View {
        NavigationStack {
            mapLayer
                .safeAreaInset(edge: .top) { regionBar }
                .navigationTitle("Map")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { ScopeMenu() }
                    ToolbarItem(placement: .topBarTrailing) { FilterMenu() }
                }
                .toolbarBackground(Theme.bg, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .onAppear {
                    if locationManager.authorizationStatus == .notDetermined {
                        locationManager.requestWhenInUseAuthorization()
                    }
                }
                .sheet(item: $selected) { s in
                    InstitutionSheet(source: s)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
        }
    }

    private struct PinData: Identifiable {
        let source: Source
        let coordinate: CLLocationCoordinate2D
        let count: Int
        var id: String { source.id }
    }

    private var pins: [PinData] {
        let counts: [String: Int] = store.countsBySource()
        var out: [PinData] = []
        for s in store.sources where store.sourceVisible(s) {
            guard let c = Coords.of(s.id) else { continue }
            out.append(PinData(source: s, coordinate: c, count: counts[s.id] ?? 0))
        }
        return out.sorted { $0.count < $1.count }
    }

    private var mapLayer: some View {
        let data: [PinData] = pins
        return Map(position: $position) {
            ForEach(data) { p in
                Annotation(p.source.name, coordinate: p.coordinate, anchor: .center) {
                    pinButton(p)
                }
                .annotationTitles(.hidden)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    private func pinButton(_ p: PinData) -> some View {
        let color: Color = Theme.borough(p.source.borough)
        let isSelected: Bool = selected?.id == p.source.id
        return PinView(color: color, count: p.count, selected: isSelected)
            .onTapGesture { selected = p.source }
            .accessibilityLabel("\(p.source.name), \(p.count) listings")
            .accessibilityAddTraits(.isButton)
    }


    private var regionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["All", "Manhattan", "Brooklyn", "Queens"], id: \.self) { name in
                    Button {
                        withAnimation { position = .region(Self.regions[name]!) }
                    } label: {
                        HStack(spacing: 6) {
                            if name != "All" { Circle().fill(Theme.borough(name)).frame(width: 8, height: 8) }
                            Text(name)
                        }
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
    }
}

struct PinView: View {
    let color: Color
    let count: Int
    var selected = false

    var body: some View {
        let size: CGFloat = count > 0 ? 20 + min(CGFloat(count).squareRoot() * 4, 16) : 12
        ZStack {
            Circle()
                .fill(count > 0 ? color : Theme.bg.opacity(0.85))
                .overlay(Circle().stroke(selected ? Theme.fg : (count > 0 ? Theme.bg : color),
                                         lineWidth: selected ? 3 : 2))
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.bg)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        .contentShape(Circle().inset(by: -8))
    }
}

/// Institution listings presented over the map; has its own browser so links work inside the sheet.
struct InstitutionSheet: View {
    let source: Source
    @State private var web: WebLink?

    var body: some View {
        NavigationStack {
            InstitutionDetail(source: source)
        }
        .environment(\.openWeb) { web = WebLink(url: $0) }
        .sheet(item: $web) { SafariView(url: $0.url).ignoresSafeArea() }
    }
}
