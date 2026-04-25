import SwiftUI

struct DateRangeFilterSheet: View {
    @Binding var dateRange: ClosedRange<Date>
    @Binding var isPresented: Bool
    var onApply: (() -> Void)? = nil

    @State private var startDate: Date
    @State private var endDate: Date

    init(
        dateRange: Binding<ClosedRange<Date>>,
        isPresented: Binding<Bool>,
        onApply: (() -> Void)? = nil
    ) {
        _dateRange = dateRange
        _isPresented = isPresented
        self.onApply = onApply
        _startDate = State(initialValue: dateRange.wrappedValue.lowerBound)
        _endDate = State(initialValue: dateRange.wrappedValue.upperBound)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Select") {
                    Button("Today") {
                        let today = Calendar.current.startOfDay(for: Date())
                        startDate = today
                        endDate = Date()
                    }

                    Button("Last 7 Days") {
                        endDate = Date()
                        startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
                    }

                    Button("Last 30 Days") {
                        endDate = Date()
                        startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
                    }

                    Button("All Time") {
                        startDate = Date.distantPast
                        endDate = Date()
                    }
                }

                Section("Custom Range") {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Filter by Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        dateRange = startDate...endDate
                        onApply?()
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
