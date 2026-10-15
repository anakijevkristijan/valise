import SwiftUI

/// Еден календар за целото патување: прв допир = поаѓање, втор допир = враќање.
struct DateRangeCalendar: View {
    @Binding var start: Date
    @Binding var end: Date

    @State private var month: Date
    @State private var selectingEnd = false

    private let minimum = Date().startOfDay

    init(start: Binding<Date>, end: Binding<Date>) {
        _start = start
        _end = end
        _month = State(initialValue: DateRangeCalendar.firstOfMonth(start.wrappedValue))
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.locale = AppLanguage.current.locale
        return cal
    }

    private static func firstOfMonth(_ date: Date) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            selectionHeader
            Hairline()
            monthHeader
            weekdayRow
            daysGrid
        }
        .padding(18)
        .luxCard(padding: 0)
        .sensoryFeedback(.selection, trigger: start)
        .sensoryFeedback(.selection, trigger: end)
    }

    // MARK: Избрано

    private var selectionHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            endpoint(label: L("Поаѓање", "Departure"), date: start, active: !selectingEnd)
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity)
            endpoint(label: L("Враќање", "Return"), date: selectingEnd ? nil : end, active: selectingEnd)
        }
    }

    private func endpoint(label: String, date: Date?, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.sans(9, .semibold))
                .tracking(1.6)
                .foregroundStyle(active ? Theme.gold : Theme.muted)
            if let date {
                Text(Fmt.ticketDate(date))
                    .font(.codes(26))
                    .foregroundStyle(Theme.ink)
                Text(Fmt.weekdayShort(date).capitalized)
                    .font(.sans(11))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                Text("—")
                    .font(.codes(26))
                    .foregroundStyle(Theme.muted)
                Text(L("избери ден", "pick a day"))
                    .font(.sans(11))
                    .foregroundStyle(Theme.gold)
            }
        }
        .frame(minWidth: 90, alignment: .leading)
    }

    // MARK: Месец

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = AppLanguage.current.locale
        f.dateFormat = "LLLL yyyy"
        return f.string(from: month).capitalized
    }

    private var canGoBack: Bool {
        month > DateRangeCalendar.firstOfMonth(minimum)
    }

    private var monthHeader: some View {
        HStack {
            Text(monthTitle)
                .font(.serif(20))
                .foregroundStyle(Theme.ink)
            Spacer()
            HStack(spacing: 6) {
                monthButton("chevron.left", enabled: canGoBack) { shiftMonth(-1) }
                monthButton("chevron.right", enabled: true) { shiftMonth(1) }
            }
        }
    }

    private func monthButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(enabled ? Theme.navy : Theme.muted.opacity(0.4))
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.75))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.easeInOut(duration: 0.2)) { month = next }
        }
    }

    private var weekdayRow: some View {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        let ordered = Array(symbols[shift...] + symbols[..<shift])
        return HStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(String(symbol.replacingOccurrences(of: ".", with: "").prefix(3)).uppercased())
                    .font(.sans(9, .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Денови

    private var monthDays: [Date?] {
        let cal = calendar
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = cal.component(.weekday, from: month)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: month) {
                cells.append(date.startOfDay)
            }
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var daysGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let s = start.startOfDay
        let e = end.startOfDay
        let isPast = day < minimum
        let isStart = day == s
        let isEnd = !selectingEnd && day == e
        let inRange = !selectingEnd && day >= s && day <= e && s != e
        let leftBand = inRange && day > s
        let rightBand = inRange && day < e
        let isToday = day == minimum
        let band = Theme.navy.opacity(0.07)

        return Button {
            select(day)
        } label: {
            ZStack {
                HStack(spacing: 0) {
                    Rectangle().fill(leftBand ? band : Color.clear)
                    Rectangle().fill(rightBand ? band : Color.clear)
                }
                .frame(height: 38)

                if isStart || isEnd {
                    Circle()
                        .fill(Theme.navy)
                        .frame(width: 38, height: 38)
                } else if isToday {
                    Circle()
                        .strokeBorder(Theme.gold.opacity(0.6), lineWidth: 0.75)
                        .frame(width: 34, height: 34)
                }

                Text(Fmt.day(day))
                    .font(.codes(17))
                    .foregroundStyle(isStart || isEnd ? Theme.goldLight : (isPast ? Theme.muted.opacity(0.4) : Theme.ink))
            }
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    private func select(_ day: Date) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if selectingEnd {
                if day < start.startOfDay {
                    start = day
                    end = day
                } else {
                    end = day
                    selectingEnd = false
                }
            } else {
                start = day
                end = day
                selectingEnd = true
            }
        }
    }
}
