import SwiftUI
import MapKit
import SwiftData

struct VisitDetailView: View {
    @Bindable var visit: Visit
    @Bindable var viewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var notesText: String = ""
    @FocusState private var isNotesFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Map
                mapSection

                // Location Info
                locationInfoSection

                // Time Info
                timeInfoSection

                // Notes
                notesSection

                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Visit Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notesText = visit.notes ?? ""
        }
        .alert("Delete Visit?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteVisit(visit)
                dismiss()
            }
        } message: {
            Text("This visit will be permanently deleted.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNotesFieldFocused = false
                    saveNotes()
                }
            }
        }
    }

    // MARK: - Sections

    private var mapSection: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: visit.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Marker(visit.displayName, coordinate: visit.coordinate)
                .tint(visit.isCurrentVisit ? .blue : .red)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var locationInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(visit.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if visit.isCurrentVisit {
                    Text("Now")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            if let address = visit.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Coordinates (for debugging/reference)
            Text(String(format: "%.6f, %.6f", visit.latitude, visit.longitude))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var timeInfoSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arrived")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(visit.arrivedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.body)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Departed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let departed = visit.departedAt {
                        Text(departed.formatted(date: .abbreviated, time: .shortened))
                            .font(.body)
                    } else {
                        Text("Still here")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding()

            Divider()

            HStack {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(visit.formattedDuration)
                    .font(.title3)
                    .fontWeight(.medium)
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Add notes about this visit...", text: $notesText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .focused($isNotesFieldFocused)
                .onChange(of: isNotesFieldFocused) { _, focused in
                    if !focused {
                        saveNotes()
                    }
                }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Open in Maps
            Button {
                openInMaps()
            } label: {
                HStack {
                    Image(systemName: "map")
                    Text("Open in Maps")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            // Delete
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Visit")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Actions

    private func saveNotes() {
        viewModel.updateVisitNotes(visit, notes: notesText)
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: visit.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = visit.displayName
        mapItem.openInMaps(launchOptions: nil)
    }
}

#Preview {
    NavigationStack {
        VisitDetailView(
            visit: Visit.preview,
            viewModel: LocationViewModel(
                modelContext: try! ModelContainer(for: Visit.self).mainContext,
                locationManager: LocationManager()
            )
        )
    }
}
