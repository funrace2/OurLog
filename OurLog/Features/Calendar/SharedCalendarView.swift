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
    @State private var showEditor = false
    @State private var editingEvent: CalendarEvent?

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
            .navigationTitle("우리 달력")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingEvent = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                EventEditorView(event: editingEvent, defaultDate: selectedDate)
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
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.primary)
                    .frame(width: 32, height: 32)
                    .background(palette.primarySoft, in: .circle)
            }

            Spacer()

            Text(visibleMonth.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "ko_KR"))))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.textPrimary)

            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.primary)
                    .frame(width: 32, height: 32)
                    .background(palette.primarySoft, in: .circle)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(["일", "월", "화", "수", "목", "금", "토"].enumerated()), id: \.offset) { index, day in
                Text(day)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(weekdayColor(index))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdayColor(_ index: Int) -> Color {
        switch index {
        case 0: .red.opacity(0.75)
        case 6: .blue.opacity(0.7)
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
                    editingEvent = nil
                    showEditor = true
                })
            )

            if events.isEmpty && anniversaries.isEmpty {
                CuteCard {
                    EmptyStateView(
                        emoji: "🗓️",
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
                                editingEvent = event
                                showEditor = true
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
                .font(.system(size: 14, weight: isSelected || isToday ? .heavy : .medium, design: .rounded))
                .foregroundStyle(textColor)
                .frame(width: 30, height: 30)
                .background {
                    if isSelected {
                        Circle().fill(palette.primary)
                    } else if isToday {
                        Circle().strokeBorder(palette.primary, lineWidth: 1.5)
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
        if isSelected { return .white }

        let weekday = Calendar.dday.component(.weekday, from: date)
        switch weekday {
        case 1: return .red.opacity(0.8)
        case 7: return .blue.opacity(0.75)
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
                    .font(.system(size: 15, weight: .bold, design: .rounded))
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
                .font(.system(size: 12, design: .rounded))
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

#Preview {
    SharedCalendarView()
        .environment(AppEnvironment.makeAppState())
        .environment(\.palette, AppTheme.peach.palette)
}
