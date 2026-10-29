import SwiftUI

struct ImportFileSelection: Identifiable {
    let id = UUID()
    let url: URL
}

struct ImportPreviewView: View {
    let url: URL
    let viewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .reading
    @State private var options = ImportOptions()

    private enum Phase {
        case reading
        case ready(ImportPreview)
        case saving
        case complete(ImportCommitResult)
        case failed(String)
    }

    private var isSaving: Bool {
        if case .saving = phase { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                switch phase {
                case .reading:
                    Section { ProgressView("Reading and checking duplicates...") }
                case .saving:
                    Section { ProgressView("Saving import...") }
                case .ready(let preview):
                    review(preview)
                case .complete(let result):
                    Section("Import Complete") {
                        Text(result.summary).accessibilityIdentifier("import-completion-summary")
                    }
                case .failed(let message):
                    Section("Import Failed") {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Review Import")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("import-review-screen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .complete = phase {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Cancel", role: .cancel) { dismiss() }
                            .disabled(isSaving)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .task {
            do {
                let preview = try await viewModel.prepareImport(from: url)
                try Task.checkCancellation()
                options.includeVisits = !preview.payload.visits.isEmpty
                options.includePoints = !preview.payload.points.isEmpty
                phase = .ready(preview)
            } catch is CancellationError {
                // Closing the sheet cancels preparation without writing anything.
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private func review(_ preview: ImportPreview) -> some View {
        Section("File") {
            LabeledContent("Name", value: preview.fileName)
            LabeledContent("Format", value: preview.payload.format.displayName)
            if let range = preview.payload.dateRange {
                LabeledContent("From", value: range.lowerBound.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("To", value: range.upperBound.formatted(date: .abbreviated, time: .shortened))
            }
        }
        Section("Import Options") {
            Toggle("Visits", isOn: $options.includeVisits)
                .disabled(preview.payload.visits.isEmpty)
                .accessibilityIdentifier("import-include-visits")
            Toggle("Points", isOn: $options.includePoints)
                .disabled(preview.payload.points.isEmpty)
                .accessibilityIdentifier("import-include-points")
            Text("Duplicates are always skipped. Existing records are never changed.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        Section("Preview") {
            LabeledContent("New visits", value: (options.includeVisits ? preview.newVisitCount : 0).formatted())
            LabeledContent("New points", value: (options.includePoints ? preview.newPointCount : 0).formatted())
            LabeledContent("Duplicate visits", value: (options.includeVisits ? preview.duplicateVisitCount : 0).formatted())
            LabeledContent("Duplicate points", value: (options.includePoints ? preview.duplicatePointCount : 0).formatted())
            if preview.payload.invalidRecordCount > 0 {
                LabeledContent("Invalid records skipped", value: preview.payload.invalidRecordCount.formatted())
            }
            if preview.payload.unsupportedRecordCount > 0 {
                LabeledContent("Unsupported entries skipped", value: preview.payload.unsupportedRecordCount.formatted())
            }
            if preview.payload.format == .googleRaw {
                Text("Raw location history contains points only. Visits are not inferred in this version.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        Section {
            Text("Files are processed locally on this device. Import does not sign into Google, upload your history, or look up place names.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Duplicate matching is approximate. Review the counts before importing.")
                .font(.footnote).foregroundStyle(.secondary)
            if selectedCount(preview) == 0 {
                Text("No new records selected.")
            }
            Button {
                phase = .saving
                Task {
                    do {
                        phase = .complete(try await viewModel.commitImport(preview, options: options))
                    } catch {
                        phase = .failed(error.localizedDescription)
                    }
                }
            } label: {
                Text("Import Selected Records").frame(maxWidth: .infinity)
            }
            .buttonStyle(TEActionButtonStyle(emphasis: .primary))
            .disabled(selectedCount(preview) == 0)
            .accessibilityIdentifier("confirm-import")
        }
    }

    private func selectedCount(_ preview: ImportPreview) -> Int {
        (options.includeVisits ? preview.newVisitCount : 0) + (options.includePoints ? preview.newPointCount : 0)
    }
}
