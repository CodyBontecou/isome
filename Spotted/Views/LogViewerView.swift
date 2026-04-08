import SwiftUI

struct LogViewerView: View {
    @ObservedObject private var logManager = LogManager.shared
    @State private var showingCopyConfirmation = false

    var body: some View {
        ZStack {
            TE.surface.ignoresSafeArea()

            if logManager.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(TE.textMuted)
                    Text("NO LOG ENTRIES")
                        .font(TE.mono(.caption, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(TE.textMuted)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(logManager.entries.reversed()) { entry in
                            logRow(entry)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("LOGS")
                    .font(TE.mono(.caption, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(TE.textMuted)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !logManager.entries.isEmpty {
                    Button {
                        UIPasteboard.general.string = logManager.exportText
                        showingCopyConfirmation = true
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TE.accent)
                    }
                    Button {
                        logManager.clear()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TE.danger)
                    }
                }
            }
        }
        .alert("Copied to Clipboard", isPresented: $showingCopyConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }

    private func logRow(_ entry: LogManager.LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.display)
                .font(TE.mono(.caption2, weight: .regular))
                .foregroundStyle(colorForLevel(entry.level))
                .lineLimit(nil)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func colorForLevel(_ level: LogManager.LogEntry.Level) -> Color {
        switch level {
        case .info: return TE.textPrimary
        case .warning: return TE.warning
        case .error: return TE.danger
        }
    }
}
