import SwiftUI
import KaiiFoodCore

struct DiaryDatePicker: View {
    @Binding var selection: Date
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var scheme
    @State private var showMonth = false
    @ScaledMetric(relativeTo: .body) private var dayWidth: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 68

    private var dates: DiaryCalendar { DiaryCalendar(calendar: calendar) }
    private var week: [Date] { dates.week(containing: selection) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    monthButton.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    navigationButtons
                }
                VStack(alignment: .leading, spacing: 4) {
                    monthButton
                    navigationButtons
                }
            }
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 4) {
                            ForEach(week, id: \.self) { day in
                                dayButton(day)
                                    .frame(width: max(dayWidth, (geometry.size.width - 24) / 7))
                                    .id(day)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .onAppear { proxy.scrollTo(calendar.startOfDay(for: selection), anchor: .center) }
                    .onChange(of: selection) { _, day in
                        proxy.scrollTo(calendar.startOfDay(for: day), anchor: .center)
                    }
                }
            }
            .frame(height: rowHeight)
            Rectangle().fill(Palette.accent.opacity(0.15)).frame(height: 1)
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showMonth) { DiaryMonthPicker(selection: $selection) }
    }

    private var monthButton: some View {
        Button { showMonth = true } label: {
            HStack(spacing: 7) {
                Text(selection.uiFormatted(.dateTime.year().month(.wide)))
                    .font(.headline)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .foregroundStyle(Palette.accent)
        .accessibilityLabel(L10n.text("选择日期，{0}", selection.uiFormatted(date: .complete, time: .omitted)))
        .accessibilityHint(L10n.text("打开月历"))
    }

    private var navigationButtons: some View {
        HStack(spacing: 2) {
            Button(L10n.text("今天")) { selection = Date() }
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 8).frame(minHeight: 44)
                .accessibilityLabel(L10n.text("回到今天"))
            Button { selection = dates.movingWeeks(-1, from: selection) } label: {
                Image(systemName: "chevron.left").font(.subheadline.weight(.medium))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.accessibilityLabel(L10n.text("上一周"))
            Button { selection = dates.movingWeeks(1, from: selection) } label: {
                Image(systemName: "chevron.right").font(.subheadline.weight(.medium))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.accessibilityLabel(L10n.text("下一周"))
        }
        .foregroundStyle(Palette.accent)
    }

    private func dayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selection)
        let today = calendar.isDateInToday(day)
        let selectedInk: Color = scheme == .dark ? .black : .white
        return Button { selection = dates.selecting(day, preservingTimeFrom: selection) } label: {
            VStack(spacing: 5) {
                Text(day.uiFormatted(.dateTime.weekday(.narrow)))
                    .font(.caption)
                    .foregroundStyle(selected ? selectedInk.opacity(0.8) : Color.secondary)
                Text("\(calendar.component(.day, from: day))")
                    .font(.body.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(selected ? selectedInk : Color.primary)
                Circle().fill(today ? (selected ? selectedInk : Palette.accent) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity).frame(height: rowHeight)
            .background(selected ? Palette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel(day.uiFormatted(date: .complete, time: .omitted))
        .accessibilityValue(today ? L10n.text("今天") : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct DiaryMonthPicker: View {
    @Binding var selection: Date
    let title: String
    let allowedRange: ClosedRange<Date>?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var month: Date

    init(selection: Binding<Date>, title: String = L10n.text("选择日期"), in allowedRange: ClosedRange<Date>? = nil) {
        _selection = selection
        self.title = title
        self.allowedRange = allowedRange
        let initialMonth = allowedRange.map {
            min(max(selection.wrappedValue, $0.lowerBound), $0.upperBound)
        } ?? selection.wrappedValue
        _month = State(initialValue: initialMonth)
    }

    private var dates: DiaryCalendar { DiaryCalendar(calendar: calendar) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    monthNavigation
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 4) {
                            ForEach(dates.monthDays(containing: month), id: \.self) { day in
                                accessibleDayButton(day)
                            }
                        }
                    } else {
                        monthGrid
                    }
                }
                .padding(20).frame(maxWidth: 460).frame(maxWidth: .infinity)
            }
            .background(Palette.paper(scheme))
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("今天")) { select(Date()) }
                        .disabled(!isSelectable(Date()))
                }
            }
            #if os(macOS)
            .frame(minWidth: 380, minHeight: 440)
            #else
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
        .tint(Palette.accent)
    }

    private var monthNavigation: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                monthTitle.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                monthArrows
            }
            VStack(alignment: .leading, spacing: 4) {
                monthTitle
                monthArrows
            }
        }
    }

    private var monthTitle: some View {
        Text(month.uiFormatted(.dateTime.year().month(.wide)))
            .font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
    }

    private var monthArrows: some View {
        HStack(spacing: 2) {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }.accessibilityLabel(L10n.text("上个月")).disabled(!canShowMonth(offset: -1))
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }.accessibilityLabel(L10n.text("下个月")).disabled(!canShowMonth(offset: 1))
        }.buttonStyle(.plain).foregroundStyle(Palette.accent)
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
            ForEach(Array(dates.week(containing: month).enumerated()), id: \.offset) { _, day in
                Text(day.uiFormatted(.dateTime.weekday(.narrow)))
                    .font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
            }
            ForEach(dates.monthGrid(containing: month), id: \.self) { day in
                monthDayButton(day)
            }
        }
    }

    private func monthDayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selection)
        let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let selectedInk: Color = scheme == .dark ? .black : .white
        return Button { select(day) } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.body.weight(selected ? .semibold : .regular)).monospacedDigit()
                .foregroundStyle(selected ? selectedInk : (inMonth ? Color.primary : Color.secondary))
                .frame(maxWidth: .infinity).frame(minHeight: 44)
                .background(selected ? Palette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if calendar.isDateInToday(day) && !selected {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.accent.opacity(0.5), lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable(day))
        .opacity(isSelectable(day) ? 1 : 0.3)
        .accessibilityLabel(day.uiFormatted(date: .complete, time: .omitted))
        .accessibilityValue(calendar.isDateInToday(day) ? L10n.text("今天") : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func accessibleDayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selection)
        return Button { select(day) } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(day.uiFormatted(.dateTime.month().day().weekday(.wide)))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark") }
            }
            .font(.body).padding(.vertical, 12).padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Palette.accent.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(selected ? Palette.accent : .primary)
        .disabled(!isSelectable(day))
        .opacity(isSelectable(day) ? 1 : 0.3)
        .accessibilityLabel(day.uiFormatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shiftMonth(_ offset: Int) {
        guard canShowMonth(offset: offset) else { return }
        let first = calendar.dateInterval(of: .month, for: month)?.start ?? month
        month = calendar.date(byAdding: .month, value: offset, to: first) ?? month
    }

    private func canShowMonth(offset: Int) -> Bool {
        guard let allowedRange else { return true }
        let first = calendar.dateInterval(of: .month, for: month)?.start ?? month
        guard let next = calendar.date(byAdding: .month, value: offset, to: first),
              let interval = calendar.dateInterval(of: .month, for: next),
              let last = calendar.date(byAdding: .day, value: -1, to: interval.end) else { return false }
        return calendar.compare(last, to: allowedRange.lowerBound, toGranularity: .day) != .orderedAscending
            && calendar.compare(interval.start, to: allowedRange.upperBound, toGranularity: .day) != .orderedDescending
    }

    private func isSelectable(_ day: Date) -> Bool {
        guard let allowedRange else { return true }
        return calendar.compare(day, to: allowedRange.lowerBound, toGranularity: .day) != .orderedAscending
            && calendar.compare(day, to: allowedRange.upperBound, toGranularity: .day) != .orderedDescending
    }

    private func select(_ day: Date) {
        guard isSelectable(day) else { return }
        selection = dates.selecting(day, preservingTimeFrom: selection)
        dismiss()
    }
}
