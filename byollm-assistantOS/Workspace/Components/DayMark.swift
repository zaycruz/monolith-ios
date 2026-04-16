//
//  DayMark.swift
//  Workspace
//
//  Day separator — "Today · Apr 15" centered between hairline rules.
//  v0.3 typography: IBM Plex Sans 12pt weight 600 (was JetBrains Mono 10).
//

import SwiftUI

struct DayMark: View {
    let date: Date

    init(date: Date) { self.date = date }

    var body: some View {
        HStack(spacing: MonolithTheme.Spacing.md) {
            line
            Text(label)
                .font(MonolithFont.sans(size: 12, weight: .semibold))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            line
        }
        .padding(.vertical, MonolithTheme.Spacing.md)
    }

    private var line: some View {
        Rectangle()
            .fill(MonolithTheme.Glass.border)
            .frame(height: 1)
    }

    private var label: String {
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let datePart = df.string(from: date)

        if cal.isDateInToday(date) {
            return "Today · \(datePart)"
        } else if cal.isDateInYesterday(date) {
            return "Yesterday · \(datePart)"
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
