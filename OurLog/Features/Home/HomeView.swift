//
//  HomeView.swift
//  OurLog
//
//  디데이 · 다가오는 기념일 · 고양이 근황을 한 화면에 모은다.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    @State private var showSettings = false
    @State private var showAddAnniversary = false

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        if app.couple?.isWaitingForPartner == true {
                            InviteCard()
                        }

                        DdayCard()
                        CatSummaryCard()
                        AnniversarySection(onAdd: { showAddAnniversary = true })
                        TodaySection()
                        RecentDiarySection()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .paperTitle("우리집")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showAddAnniversary) {
                AnniversaryEditorView()
            }
        }
    }
}

// MARK: - 초대 카드

private struct InviteCard: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @State private var copied = false

    var body: some View {
        CuteCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("상대방을 기다리는 중이에요")
                    .font(.hand(22, bold: true))
                    .foregroundStyle(palette.textPrimary)

                Text("이 코드를 알려주면 둘의 기록이 이어져요")
                    .font(.hand(18))
                    .foregroundStyle(palette.textSecondary)

                HStack {
                    Text(app.couple?.inviteCode ?? "------")
                        .font(.hand(35, bold: true))
                        .kerning(6)
                        .foregroundStyle(palette.primary)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = app.couple?.inviteCode
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            copied = false
                        }
                    } label: {
                        Label(copied ? "복사됨" : "복사", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.hand(18, bold: true))
                    }
                    .buttonStyle(.softPlain)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .sketchBox(seed: 270, fill: palette.primarySoft, roughness: 1.3, lineWidth: 1.6)
            }
        }
    }
}

// MARK: - 디데이

private struct DdayCard: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        CuteCard(padding: 22) {
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    memberBadge(app.me)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(palette.accent)
                    memberBadge(app.partner)
                }

                VStack(spacing: 2) {
                    Text("우리 만난 지")
                        .font(.hand(18))
                        .foregroundStyle(palette.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(app.couple?.daysTogether ?? 0)")
                            .font(.hand(70, bold: true))
                            .contentTransition(.numericText())
                        Text("일")
                            .font(.hand(30, bold: true))
                    }
                    .foregroundStyle(palette.primary)
                }

                if let startDate = app.couple?.startDate {
                    Text(startDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ko_KR"))))
                        .font(.hand(16))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 12)
                        .sketchBox(seed: 263, fill: palette.surfaceAlt, roughness: 1.1, lineWidth: 1.4)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func memberBadge(_ member: Partner?) -> some View {
        VStack(spacing: 4) {
            Text(member?.emoji ?? "❔")
                .font(.system(size: 26))
                .sketchCircle(fill: palette.primarySoft, seed: 249, size: 52)

            Text(member?.displayName ?? "상대방")
                .font(.hand(16, bold: true))
                .foregroundStyle(member == nil ? palette.textSecondary : palette.textPrimary)
                .lineLimit(1)
        }
        .frame(width: 72)
    }
}

// MARK: - 고양이 요약

private struct CatSummaryCard: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationLink {
            CatRoomView()
        } label: {
            CuteCard {
                HStack(spacing: 14) {
                    CatPortrait(
                        stage: app.cat.stage,
                        accessories: app.equippedAccessories,
                        size: 84
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(app.cat.name)
                                .font(.hand(22, bold: true))
                                .foregroundStyle(palette.textPrimary)
                                .lineLimit(1)
                            Chip(text: "\(app.cat.stage.rawValue)단계")
                        }

                        Text(app.cat.stage.tagline)
                            .font(.hand(16))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)

                        AffectionBar(progress: app.cat.progressToNextStage)
                            .padding(.top, 2)

                        if let remaining = app.cat.affectionToNextStage {
                            Text("다음 단계까지 \(remaining)")
                                .font(.hand(15))
                                .foregroundStyle(palette.textSecondary)
                        } else {
                            Text("최종 진화 완료! 🎉")
                                .font(.hand(15, bold: true))
                                .foregroundStyle(palette.accent)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 기념일

private struct AnniversarySection: View {
    let onAdd: () -> Void

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            SectionHeader(
                title: "다가오는 기념일",
                systemImage: "gift.fill",
                action: (title: "추가", handler: onAdd)
            )

            let upcoming = Array(app.upcomingAnniversaries.prefix(4))

            if upcoming.isEmpty {
                CuteCard {
                    EmptyStateView(
                        title: "아직 등록된 기념일이 없어요",
                        message: "생일이나 특별한 날을 추가해 보세요"
                    )
                }
            } else {
                CuteCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, anniversary in
                            AnniversaryRow(anniversary: anniversary)
                            if index < upcoming.count - 1 {
                                SketchDivider().padding(.leading, 56)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct AnniversaryRow: View {
    let anniversary: Anniversary

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Text(anniversary.emoji)
                .font(.system(size: 20))
                .sketchCircle(fill: palette.primarySoft, seed: 256, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(anniversary.title)
                    .font(.hand(20, bold: true))
                    .foregroundStyle(palette.textPrimary)
                Text(anniversary.nextOccurrence.formatted(.dateTime.month().day().locale(Locale(identifier: "ko_KR"))))
                    .font(.hand(16))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            if anniversary.isToday {
                Chip(text: "오늘!", systemImage: "party.popper.fill", tint: palette.accent)
            } else {
                Text("D-\(anniversary.daysRemaining)")
                    .font(.hand(20, bold: true))
                    .foregroundStyle(palette.primary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - 오늘 일정

private struct TodaySection: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    private var todayEvents: [CalendarEvent] {
        app.events
            .filter { $0.occurs(on: .now) }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        if !todayEvents.isEmpty {
            VStack(spacing: 10) {
                SectionHeader(title: "오늘 일정", systemImage: "calendar")

                CuteCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(todayEvents) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 최근 일기

private struct RecentDiarySection: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        let recent = Array(app.diaries.prefix(5))

        if !recent.isEmpty {
            VStack(spacing: 10) {
                SectionHeader(title: "최근 일기", systemImage: "book.closed.fill")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recent) { entry in
                            NavigationLink {
                                DiaryDetailView(entry: entry)
                            } label: {
                                DiaryThumbnail(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - 편의

extension AppState {
    /// 착용 중인 액세서리를 슬롯별 객체로 풀어 준다.
    var equippedAccessories: [AccessorySlot: CatAccessory] {
        cat.equippedAccessories.reduce(into: [:]) { result, pair in
            result[pair.key] = DecorCatalog.accessory(id: pair.value)
        }
    }

    /// 배치한 방 아이템을 슬롯별 객체로 풀어 준다.
    var placedRoomItems: [RoomSlot: RoomItem] {
        cat.placedRoomItems.reduce(into: [:]) { result, pair in
            result[pair.key] = DecorCatalog.roomItem(id: pair.value)
        }
    }
}
