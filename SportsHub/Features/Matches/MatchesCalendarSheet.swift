import SwiftUI

struct MatchesCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftDate: Date
    let onApply: (Date) -> Void

    init(selectedDate: Date, onApply: @escaping (Date) -> Void) {
        _draftDate = State(initialValue: selectedDate)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DatePicker(
                        "matches.calendarDate",
                        selection: $draftDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .accessibilityHint(Text("matches.calendarDateHint"))
                    .accessibilityIdentifier("matches.calendar.datePicker")

                    Button {
                        draftDate = Date()
                    } label: {
                        Label("matches.today", systemImage: "calendar.badge.clock")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(Text("matches.calendarTodayHint"))
                    .accessibilityIdentifier("matches.calendar.today")
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("matches.calendarTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("matches.cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("matches.calendar.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("matches.applyDate") {
                        onApply(draftDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("matches.calendar.apply")
                }
            }
            .accessibilityIdentifier("matches.calendar.sheet")
        }
    }
}
