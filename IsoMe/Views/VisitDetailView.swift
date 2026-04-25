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
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)

                mapSection
                    .padding(.horizontal, DS.Spacing.lg)

                statGrid
                    .padding(.horizontal, DS.Spacing.lg)

                addressCard
                    .padding(.horizontal, DS.Spacing.lg)

                notesCard
                    .padding(.horizontal, DS.Spacing.lg)

                actionsCard
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .background(DS.Color.background.ignoresSafeArea())
        .navigationTitle("Visit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notesText = visit.notes ?? ""
        }
        .alert("Delete visit?", isPresented: $showingDeleteConfirmation) {
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            CategoryIcon(symbol: visitSymbol, palette: visitPalette, size: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(visit.displayName)
                    .font(DS.Font.title())
                    .foregroundStyle(DS.Color.textPrimary)
                    .lineLimit(2)

                Text(headerSubtitle)
                    .font(DS.Font.body(.medium))
                    .foregroundStyle(DS.Color.textMuted)
            }

            Spacer(minLength: 0)

            if visit.isCurrentVisit {
                StatusDot(state: .on)
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: visit.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Annotation(visit.displayName, coordinate: visit.coordinate, anchor: .bottom) {
                VisitMarker(visit: visit, isSelected: false)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: 0, y: DS.Shadow.cardY)
    }

    // MARK: - Stats grid

    private var statGrid: some View {
        let columns = [GridItem(.flexible(), spacing: DS.Spacing.md), GridItem(.flexible(), spacing: DS.Spacing.md)]
        return LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            StatCard(
                symbol: "flag.fill",
                palette: .green,
                value: timeValue(visit.arrivedAt),
                unit: timePeriod(visit.arrivedAt),
                label: "Arrived"
            )

            if let departed = visit.departedAt {
                StatCard(
                    symbol: "flag.checkered",
                    palette: .peach,
                    value: timeValue(departed),
                    unit: timePeriod(departed),
                    label: "Departed"
                )
            } else {
                StatCard(
                    symbol: "dot.radiowaves.left.and.right",
                    palette: .blue,
                    value: "Now",
                    label: "Departed"
                )
            }

            StatCard(
                symbol: "clock.fill",
                palette: .purple,
                value: visit.formattedDuration,
                label: "Duration"
            )

            StatCard(
                symbol: "calendar",
                palette: .brown,
                value: dayValue(visit.arrivedAt),
                unit: monthValue(visit.arrivedAt),
                label: "Date"
            )
        }
    }

    // MARK: - Address

    private var addressCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Location")
                    .font(DS.Font.caption(.medium))
                    .foregroundStyle(DS.Color.textMuted)
                    .textCase(.uppercase)

                if let address = visit.address {
                    Text(address)
                        .font(DS.Font.body(.medium))
                        .foregroundStyle(DS.Color.textPrimary)
                } else {
                    Text("No address available")
                        .font(DS.Font.body())
                        .foregroundStyle(DS.Color.textMuted)
                        .italic()
                }

                Text(String(format: "%.6f, %.6f", visit.latitude, visit.longitude))
                    .font(DS.Font.caption())
                    .foregroundStyle(DS.Color.textMuted)
                    .monospaced()
            }
        }
    }

    // MARK: - Notes

    private var notesCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Notes")
                    .font(DS.Font.caption(.medium))
                    .foregroundStyle(DS.Color.textMuted)
                    .textCase(.uppercase)

                TextField("Add notes about this visit…", text: $notesText, axis: .vertical)
                    .font(DS.Font.body())
                    .foregroundStyle(DS.Color.textPrimary)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .focused($isNotesFieldFocused)
                    .onChange(of: isNotesFieldFocused) { _, focused in
                        if !focused {
                            saveNotes()
                        }
                    }
            }
        }
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(spacing: DS.Spacing.sm) {
            PrimaryButton(title: "Open in Maps", action: openInMaps)

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "trash")
                    Text("Delete Visit")
                        .font(DS.Font.headline())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                        .fill(DS.Color.danger.opacity(0.12))
                )
                .foregroundStyle(DS.Color.danger)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Computed labels

    private var headerSubtitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: visit.arrivedAt)
    }

    private var visitPalette: DS.Palette {
        let lower = visit.displayName.lowercased()
        if lower.contains("home") { return .brown }
        if lower.contains("coffee") || lower.contains("cafe") || lower.contains("café") { return .peach }
        if lower.contains("beach") || lower.contains("park") { return .green }
        return .purple
    }

    private var visitSymbol: String {
        let lower = visit.displayName.lowercased()
        if lower.contains("home") { return "house.fill" }
        if lower.contains("coffee") || lower.contains("cafe") || lower.contains("café") { return "cup.and.saucer.fill" }
        if lower.contains("beach") { return "beach.umbrella.fill" }
        if lower.contains("park") { return "tree.fill" }
        if lower.contains("work") || lower.contains("office") { return "briefcase.fill" }
        if lower.contains("gym") { return "dumbbell.fill" }
        return "mappin.and.ellipse"
    }

    private func timeValue(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    private func timePeriod(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f.string(from: date)
    }

    private func dayValue(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func monthValue(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
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
