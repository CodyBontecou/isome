import SwiftUI

struct LogViewerView: View {
    @ObservedObject private var logManager = LogManager.shared
    @State private var showingCopyConfirmation = false

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            if logManager.entries.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(DS.Color.textMuted)
                    Text("No log entries")
                        .font(DS.Font.body(.medium))
                        .foregroundStyle(DS.Color.textMuted)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(logManager.entries.reversed()) { entry in
                            logRow(entry)
                        }
                    }
                    .padding(.bottom, DS.Spacing.xxl)
                }
            }
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !logManager.entries.isEmpty {
                    Button {
                        UIPasteboard.general.string = logManager.exportText
                        showingCopyConfirmation = true
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DS.Color.accent)
                    }
                    Button {
                        logManager.clear()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DS.Color.danger)
                    }
                }
            }
        }
        .alert("Copied to clipboard", isPresented: $showingCopyConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }

    private func logRow(_ entry: LogManager.LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.display)
                .font(DS.Font.mono(.caption2))
                .foregroundStyle(colorForLevel(entry.level))
                .lineLimit(nil)
                .textSelection(.enabled)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func colorForLevel(_ level: LogManager.LogEntry.Level) -> Color {
        switch level {
        case .info: return DS.Color.textPrimary
        case .warning: return DS.Color.warning
        case .error: return DS.Color.danger
        }
    }
}
