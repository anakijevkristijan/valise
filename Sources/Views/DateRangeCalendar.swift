import SwiftUI

/// Календар за целото патување.
/// Допри поаѓање → автоматски се бира враќање. Брзи траења, листање месеци со повлекување.
struct DateRangeCalendar: View {
    @Binding var start: Date
    @Binding var end: Date

    private enum Endpoint { case start, end }

    @State private var month: Date
    @State private var editing: Endpoint = .start
    @State private var monthDirection: Int = 1
    /// По изборот на враќањето календарот се собира; „Промени датуми“ го отвора повторно.
    @State private var collapsed = false

    /// Најран ден што може да се избере (пр. вториот град - не пред заминувањето од првиот).
    let earliest: Date?
    /// Изборот е готов и календарот се собра (екранот оди на следниот град).
    var onCollapse: (() -> Void)? = nil
    /// Календарот повторно се отвори („Промени датуми“).
    var onExpand: (() -> Void)? = nil
    /// Повеќе градови: „Пристигнување → Заминување“ наместо „Поаѓање → Враќање“.
    var arriveLeave = false

    private var minimum: Date { max(Date().startOfDay, earliest?.startOfDay ?? .distantPast) }

    init(start: Binding<Date>, end: Binding<Date>, earliest: Date? = nil, arriveLeave: Bool = false,
         onCollapse: (() -> Void)? = nil, onExpand: (() -> Void)? = nil) {
        _start = start
        _end = end
        self.earliest = earliest
        self.arriveLeave = arriveLeave
        self.onCollapse = onCollapse
        self.onExpand = onExpand
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
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private var hasRange: Bool { editing == .start && end.startOfDay > start.startOfDay }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            selectionHeader
            if collapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { collapsed = false }
                    onExpand?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13, weight: .light))
                        Text(L("Промени датуми", "Change dates"))
                            .font(.sans(13, .semibold))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Theme.navy)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Hairline()
                monthHeader
                VStack(spacing: 6) {
                    weekdayRow
                    daysGrid
                        .id(month)
                        .transition(.asymmetric(
                            insertion: .move(edge: monthDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                .clipped()
                quickLengths
            }
        }
        .padding(18)
        .luxCard(padding: 0)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > 50 && abs(dx) > abs(dy) * 1.5 {
                        shiftMonth(dx < 0 ? 1 : -1)
                    }
                }
        )
        .sensoryFeedback(.selection, trigger: start)
        .sensoryFeedback(.selection, trigger: end)
    }

    // MARK: Поаѓање → Враќање

    private var selectionHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            endpointBlock(.start,
                          label: arriveLeave ? L("Пристигнување", "Arrive") : L("Поаѓање", "Departure"),
                          date: start)
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Theme.gold)
                .padding(.top, 22)
            endpointBlock(.end,
                          label: arriveLeave ? L("Заминување", "Leave") : L("Враќање", "Return"),
                          date: editing == .end && end.startOfDay == start.startOfDay ? nil : end)
        }
    }

    private func endpointBlock(_ point: Endpoint, label: String, date: Date?) -> some View {
        let active = editing == point
        return Button {
            if collapsed { onExpand?() }
            withAnimation(.easeInOut(duration: 0.2)) {
                collapsed = false
                editing = point
                let target = point == .start ? start : end
                monthDirection = target >= month ? 1 : -1
                month = DateRangeCalendar.firstOfMonth(target)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.sans(9, .semibold))
                    .tracking(1.6)
                    .foregroundStyle(active ? Theme.gold : Theme.muted)
                if let date {
                    Text(Fmt.ticketDate(date))
                        .font(.codes(28))
                        .foregroundStyle(Theme.ink)
                    Text(Fmt.weekdayShort(date).capitalized)
                        .font(.sans(11))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    Text("- -")
                        .font(.codes(28))
                        .foregroundStyle(Theme.muted.opacity(0.6))
                    Text(L("избери ден", "pick a day"))
                        .font(.sans(11, .medium))
                        .foregroundStyle(Theme.gold)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? Theme.goldPale.opacity(0.7) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(active ? Theme.gold.opacity(0.5) : Theme.hairline, lineWidth: 0.75)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Месец

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = AppLanguage.current.locale
        f.dateFormat = "LLLL yyyy"
        return f.string(from: month).capitalized
    }

    private var canGoBack: Bool { month > DateRangeCalendar.firstOfMonth(minimum) }

    private var monthHeader: some View {
        HStack {
            Text(monthTitle)
                .font(.serif(21))
                .foregroundStyle(Theme.ink)
                .contentTransition(.opacity)
            Spacer()
            monthButton("chevron.left", enabled: canGoBack) { shiftMonth(-1) }
            monthButton("chevron.right", enabled: true) { shiftMonth(1) }
        }
    }

    private func monthButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(enabled ? Theme.navy : Theme.muted.opacity(0.35))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture { if enabled { action() } }
    }

    private func shiftMonth(_ delta: Int) {
        guard delta > 0 || canGoBack else { return }
        guard let next = calendar.date(byAdding: .month, value: delta, to: month) else { return }
        monthDirection = delta
        withAnimation(.easeInOut(duration: 0.25)) { month = next }
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

    private var weeks: [[Date?]] {
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
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    private var daysGrid: some View {
        VStack(spacing: 2) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 46)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let s = start.startOfDay
        let e = end.startOfDay
        let isPast = day < minimum
        let isStart = day == s
        let isEnd = hasRange && day == e
        let inRange = hasRange && day >= s && day <= e
        let leftBand = inRange && day > s
        let rightBand = inRange && day < e
        let isToday = day == minimum
        let band = Theme.navy.opacity(0.08)

        return ZStack {
            HStack(spacing: 0) {
                Rectangle().fill(leftBand ? band : Color.clear)
                Rectangle().fill(rightBand ? band : Color.clear)
            }
            .frame(height: 42)

            if isStart || isEnd {
                Circle()
                    .fill(Theme.navy)
                    .frame(width: 42, height: 42)
            } else if isToday {
                Circle()
                    .strokeBorder(Theme.gold.opacity(0.7), lineWidth: 1)
                    .frame(width: 38, height: 38)
            }

            Text(Fmt.day(day))
                .font(.codes(18))
                .foregroundStyle(isStart || isEnd ? Theme.goldLight : (isPast ? Theme.muted.opacity(0.35) : Theme.ink))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isPast else { return }
            select(day)
        }
    }

    private func select(_ day: Date) {
        withAnimation(.easeOut(duration: 0.15)) {
            switch editing {
            case .start:
                start = day
                end = day
                editing = .end
            case .end:
                if day < start.startOfDay {
                    start = day
                    end = day
                } else {
                    end = day
                    editing = .start
                    collapseSoon()
                }
            }
        }
    }

    /// Кратка пауза за да се види изборот, па календарот се собира.
    private func collapseSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if editing == .start && end.startOfDay >= start.startOfDay {
                withAnimation(.easeInOut(duration: 0.3)) { collapsed = true }
                onCollapse?()
            }
        }
    }

    // MARK: Брзи траења

    private var quickLengths: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(editing == .end
                 ? (arriveLeave ? L("Сега допри го денот кога заминуваш - или избери траење:", "Now tap the day you leave - or pick a length:")
                                : L("Сега допри го денот на враќање - или избери траење:", "Now tap your return day - or pick a length:"))
                 : (arriveLeave ? L("Брзо траење од пристигнувањето:", "Quick length from arrival:")
                                : L("Брзо траење од поаѓањето:", "Quick length from departure:")))
                .font(.sans(12))
                .foregroundStyle(editing == .end ? Theme.gold : Theme.muted)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    lengthChip(L("Викенд", "Weekend"), days: 3)
                    lengthChip(Fmt.days(5), days: 5)
                    lengthChip(L("1 недела", "1 week"), days: 7)
                    lengthChip(Fmt.days(10), days: 10)
                    lengthChip(L("2 недели", "2 weeks"), days: 14)
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func lengthChip(_ title: String, days: Int) -> some View {
        let selected = hasRange && Calendar.current.dateComponents([.day], from: start.startOfDay, to: end.startOfDay).day == days - 1
        return Text(title)
            .font(.sans(13, selected ? .semibold : .medium))
            .foregroundStyle(selected ? Theme.goldLight : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(selected ? Theme.navy : Theme.surface))
            .overlay(Capsule().strokeBorder(selected ? Theme.navy : Theme.hairline, lineWidth: 0.75))
            .contentShape(Capsule())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.15)) {
                    end = start.startOfDay.adding(days: days - 1)
                    editing = .start
                }
                collapseSoon()
            }
    }
}
