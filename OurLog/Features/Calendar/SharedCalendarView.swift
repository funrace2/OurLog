//
//  SharedCalendarView.swift
//  OurLog
//
//  둘이 같이 쓰는 달력. 일정과 기념일이 한 화면에 같이 뜬다.
//

import SwiftUI

struct SharedCalendarView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    @State private var visibleMonth = Date.now
    @State private var selectedDate = Date.now
    /// 열 편집 화면. "무엇을 열지"를 띄우는 값 자체에 담아야 띄우는 순간 확정된다.
    /// (따로 두고 동시에 바꾸면 SwiftUI 가 바뀌기 전 값으로 열어서 기존 일정이 "새 일정"으로 열렸다)
    @State private var editorTarget: EventEditorTarget?
    @State private var showMonthPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        monthCard
                        selectedDaySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .paperTitle("우리 달력")
            .toolbar {
                // 다른 달로 넘어갔거나 다른 날을 골랐을 때만 보인다
                if !isShowingToday {
                    ToolbarItem(placement: .topBarLeading) {
                        ToolbarTextButton("오늘") { goToToday() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorTarget = .new(selectedDate)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showMonthPicker) {
                MonthPickerSheet(month: visibleMonth) { picked in
                    withAnimation(.snappy) { visibleMonth = picked }
                }
                .presentationDetents([.height(340)])
            }
            .sheet(item: $editorTarget) { target in
                switch target {
                case .new(let date):
                    EventEditorView(event: nil, defaultDate: date)
                case .edit(let event):
                    EventEditorView(event: event, defaultDate: event.startDate)
                }
            }
        }
    }

    // MARK: 달력

    private var monthCard: some View {
        CuteCard(padding: 16) {
            VStack(spacing: 14) {
                monthHeader
                weekdayHeader
                dayGrid
            }
        }
        .contentShape(Rectangle())
        // 좌우로 밀면 달이 넘어간다. 세로 스크롤·날짜 탭은 그대로 두려고 가로로 확실히 민 경우만 받는다.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > 50, abs(dx) > abs(dy) * 1.5 else { return }
                    shiftMonth(dx < 0 ? 1 : -1)
                }
        )
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.primary)
                    .sketchCircle(fill: palette.primarySoft, seed: 284, size: 32)
            }

            Spacer()

            // 누르면 연·월을 골라 한 번에 넘어간다
            Button { showMonthPicker = true } label: {
                HStack(spacing: 4) {
                    Text(visibleMonth.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "ko_KR"))))
                        .font(.hand(23, bold: true))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(palette.textPrimary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.primary)
                    .sketchCircle(fill: palette.primarySoft, seed: 291, size: 32)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(["일", "월", "화", "수", "목", "금", "토"].enumerated()), id: \.offset) { index, day in
                Text(day)
                    .font(.hand(16, bold: true))
                    .foregroundStyle(weekdayColor(index))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdayColor(_ index: Int) -> Color {
        switch index {
        case 0: Theme.redPen
        case 6: Theme.bluePen
        default: palette.textSecondary
        }
    }

    private var dayGrid: some View {
        let days = monthDays()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    DayCell(
                        date: day,
                        isSelected: Calendar.dday.isDate(day, inSameDayAs: selectedDate),
                        isToday: Calendar.dday.isDateInToday(day),
                        markers: markers(for: day)
                    )
                    .onTapGesture {
                        withAnimation(.snappy) { selectedDate = day }
                    }
                } else {
                    Color.clear.frame(height: 42)
                }
            }
        }
    }

    /// 그 날에 찍을 점들의 색
    private func markers(for day: Date) -> [Color] {
        var colors: [Color] = []

        if app.events.contains(where: { $0.occurs(on: day) }) {
            colors.append(palette.primary)
        }
        if app.upcomingAnniversaries.contains(where: {
            Calendar.dday.isDate($0.nextOccurrence, inSameDayAs: day)
        }) {
            colors.append(palette.accent)
        }
        return colors
    }

    /// 월요일이 아니라 일요일 시작 기준으로 앞을 빈칸으로 채운 42칸 배열
    private func monthDays() -> [Date?] {
        let cal = Calendar.dday
        guard let interval = cal.dateInterval(of: .month, for: visibleMonth) else { return [] }

        let firstWeekday = cal.component(.weekday, from: interval.start) // 일요일 = 1
        let dayCount = cal.range(of: .day, in: .month, for: visibleMonth)?.count ?? 30

        var result: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for offset in 0..<dayCount {
            result.append(cal.date(byAdding: .day, value: offset, to: interval.start))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private func shiftMonth(_ value: Int) {
        guard let shifted = Calendar.dday.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        withAnimation(.snappy) { visibleMonth = shifted }
    }

    private var isShowingToday: Bool {
        Calendar.dday.isDate(visibleMonth, equalTo: .now, toGranularity: .month)
            && Calendar.dday.isDateInToday(selectedDate)
    }

    private func goToToday() {
        withAnimation(.snappy) {
            visibleMonth = .now
            selectedDate = .now
        }
    }

    // MARK: 선택한 날

    private var selectedDaySection: some View {
        let events = app.events
            .filter { $0.occurs(on: selectedDate) }
            .sorted { $0.startDate < $1.startDate }

        let anniversaries = app.upcomingAnniversaries.filter {
            Calendar.dday.isDate($0.nextOccurrence, inSameDayAs: selectedDate)
        }

        return VStack(spacing: 10) {
            SectionHeader(
                title: selectedDate.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ko_KR"))),
                systemImage: "calendar.badge.clock",
                action: (title: "일정 추가", handler: {
                    editorTarget = .new(selectedDate)
                })
            )

            if events.isEmpty && anniversaries.isEmpty {
                CuteCard {
                    EmptyStateView(
                        title: "이 날은 일정이 없어요",
                        message: "둘의 약속을 등록해 보세요"
                    )
                }
            } else {
                CuteCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(anniversaries) { AnniversaryRow(anniversary: $0) }

                        ForEach(events) { event in
                            Button {
                                editorTarget = .edit(event)
                            } label: {
                                EventRow(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

/// 일정 편집 화면을 무엇으로 열지
enum EventEditorTarget: Identifiable {
    case new(Date)
    case edit(CalendarEvent)

    var id: String {
        switch self {
        case .new(let date): "new-\(date.timeIntervalSince1970)"
        case .edit(let event): "edit-\(event.id)"
        }
    }
}

// MARK: - 날짜 칸

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let markers: [Color]

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.dday.component(.day, from: date))")
                .font(.hand(20, bold: isSelected || isToday))
                .foregroundStyle(textColor)
                .frame(width: 30, height: 30)
                .background {
                    let day = UInt64(Calendar.dday.component(.day, from: date))
                    if isSelected {
                        SketchCircle(seed: day &+ 900).fill(palette.primarySoft)
                        SketchCircle(seed: day &+ 900).stroke(palette.ink, lineWidth: 1.8)
                    } else if isToday {
                        SketchCircle(seed: day &+ 900).stroke(Theme.redPen, lineWidth: 2)
                    }
                }

            HStack(spacing: 3) {
                ForEach(Array(markers.enumerated()), id: \.offset) { _, color in
                    Circle().fill(color).frame(width: 4, height: 4)
                }
            }
            .frame(height: 5)
        }
        .frame(height: 42)
        .contentShape(.rect)
    }

    private var textColor: Color {
        let weekday = Calendar.dday.component(.weekday, from: date)
        switch weekday {
        case 1: return Theme.redPen
        case 7: return Theme.bluePen
        default: return palette.textPrimary
        }
    }
}

// MARK: - 일정 줄

struct EventRow: View {
    let event: CalendarEvent

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(authorColor)
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.hand(20, bold: true))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(event.isAllDay
                         ? "하루 종일"
                         : event.startDate.formatted(.dateTime.hour().minute().locale(Locale(identifier: "ko_KR"))))
                    if let place = app.place(id: event.placeID) {
                        Text("· \(place.name)").lineLimit(1)
                    }
                }
                .font(.hand(16))
                .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            Text(app.couple?.member(id: event.createdBy)?.emoji ?? "")
                .font(.system(size: 16))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(.rect)
    }

    /// 누가 만든 일정인지 색으로 구분한다.
    private var authorColor: Color {
        event.createdBy == app.me?.id ? palette.primary : palette.accent
    }
}

// MARK: - 연월 고르기

private struct MonthPickerSheet: View {
    let onPick: (Date) -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var year: Int
    @State private var month: Int

    private let years: [Int]

    init(month date: Date, onPick: @escaping (Date) -> Void) {
        self.onPick = onPick
        let cal = Calendar.dday
        let currentYear = cal.component(.year, from: .now)
        years = Array((currentYear - 30)...(currentYear + 10))
        _year = State(initialValue: cal.component(.year, from: date))
        _month = State(initialValue: cal.component(.month, from: date))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        Picker("연도", selection: $year) {
                            ForEach(years, id: \.self) { value in
                                Text(verbatim: "\(value)년").font(.hand(22)).tag(value)
                            }
                        }
                        Picker("월", selection: $month) {
                            ForEach(1...12, id: \.self) { value in
                                Text("\(value)월").font(.hand(22)).tag(value)
                            }
                        }
                    }
                    .pickerStyle(.wheel)
                    .foregroundStyle(palette.ink)

                    Button("이동하기") {
                        if let date = Calendar.dday.date(from: DateComponents(year: year, month: month, day: 1)) {
                            onPick(date)
                        }
                        dismiss()
                    }
                    .buttonStyle(.soft)
                }
                .padding(.horizontal, 20)
            }
            .paperTitle("어느 달로 갈까요?")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ToolbarTextButton("취소") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SharedCalendarView()
        .environment(AppEnvironment.makeAppState())
        .environment(\.palette, AppTheme.default.palette)
}
