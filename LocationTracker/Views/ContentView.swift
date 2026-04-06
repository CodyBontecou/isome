import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LocationViewModel?
    @State private var locationManager: LocationManager?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                TabView {
                    TodayView(viewModel: viewModel)
                        .tabItem {
                            Label("Data", systemImage: "list.bullet")
                        }

                    TrackingView(viewModel: viewModel)
                        .tabItem {
                            Label("Track", systemImage: "location.fill")
                        }

                    LocationMapView(viewModel: viewModel)
                        .tabItem {
                            Label("Map", systemImage: "map.fill")
                        }

                    SettingsView(viewModel: viewModel)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            if viewModel == nil {
                let manager = LocationManager()
                locationManager = manager
                viewModel = LocationViewModel(
                    modelContext: modelContext,
                    locationManager: manager
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidBecomeActive)) { _ in
            viewModel?.loadData()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Visit.self, LocationPoint.self], inMemory: true)
}
