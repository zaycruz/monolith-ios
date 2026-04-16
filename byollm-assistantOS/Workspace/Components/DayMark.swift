//
//  DayMark.swift
//  Workspace
//
//  Day separator — "Today · Apr 15" centered between hairline rules.
//

import SwiftUI

struct DayMark: View {
    let date: Date

    init(date: Date) { self.date = date }

    var body: some View {
        HStack(spacing: MonolithTheme.Spacing.md) {
            line
            Text(label)
                .font(MonolithFont.mono(size: 10, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
                .tracking(0.5)
            line
        }
        .padding(.vertical, MonolithTheme.Spacing.md)
    }

    private var line: some View {
        Rectangle()
            .fill(MonolithTheme.Colors.borderSoft)
            .frame(height: 1)
    }

    private var label: String {
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let datePart = df.string(from: date).uppercased()

        if cal.isDateInToday(date) {
            return "TODAY · \(datePart)"
        } else if cal.isDateInYesterday(date) {
            return "YESTERDAY · \(datePart)"
        }
        return datePart
    }
}

#Preview("DayMark") {
    VStack {
        DayMark(date: MockClock.today)
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
