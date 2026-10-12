//
//  SettingsView.swift
//  OurLog
//
//  프로필 · 색깔 테마 · 기념일 관리 · 커플 정보.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var showProfileEditor = false
    @State private var showAnniversaryList = false
    @State private var showStartDatePicker = false
    @State private var startDate = Date.now
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        profileCard
                        ThemePickerCard()
                        coupleCard
                        manageCard
                        aboutCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showProfileEditor) { ProfileEditorView() }
            .sheet(isPresented: $showAnniversaryList) { AnniversaryListView() }
            .confirmationDialog("로그아웃할까요?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("로그아웃", role: .destructive) {
                    app.signOut()
                    dismiss()
                }
            }
        }
    }

    // MARK: 프로필

    private var profileCard: some View {
        CuteCard {
            HStack(spacing: 14) {
                Text(app.me?.emoji ?? "🐣")
                    .font(.system(size: 30))
                    .frame(width: 58, height: 58)
                    .background(palette.primarySoft, in: .circle)

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.me?.displayName ?? "나")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    if let birthday = app.me?.birthday {
                        Text("생일 " + birthday.formatted(.dateTime.month().day().locale(Locale(identifier: "ko_KR"))))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                    } else {
                        Text("생일을 등록하면 기념일에 같이 떠요")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                    }
                }

                Spacer()

                Button("수정") { showProfileEditor = true }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primary)
            }
        }
    }

    // MARK: 커플

    private var coupleCard: some View {
        CuteCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "우리", systemImage: "heart.fill")

                row(label: "함께한 날", value: "\(app.couple?.daysTogether ?? 0)일")

                Button {
                    startDate = app.couple?.startDate ?? .now
                    showStartDatePicker = true
                } label: {
                    row(
                        label: "처음 만난 날",
                        value: app.couple?.startDate.formatted(
                            .dateTime.year().month().day().locale(Locale(identifier: "ko_KR"))
                        ) ?? "-",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)

                if app.couple?.isWaitingForPartner == true {
                    row(label: "초대코드", value: app.couple?.inviteCode ?? "-")
                } else if let partner = app.partner {
                    row(label: "함께하는 사람", value: "\(partner.emoji) \(partner.displayName)")
                }
            }
        }
        .sheet(isPresented: $showStartDatePicker) {
            StartDateSheet(date: $startDate)
                .presentationDetents([.height(340)])
        }
    }

    // MARK: 관리

    private var manageCard: some View {
        CuteCard(padding: 0) {
            VStack(spacing: 0) {
                Button { showAnniversaryList = true } label: {
                    menuRow(icon: "gift.fill", title: "기념일 관리")
                }
                .buttonStyle(.plain)

                Divider().overlay(palette.outline).padding(.leading, 52)

                Button {
                    Task {
                        let granted = await NotificationService.shared.requestAuthorizationIfNeeded()
                        await app.refreshNotifications()
                        app.toast = Toast(
                            text: granted ? "기념일 알림을 켰어요" : "설정에서 알림을 허용해 주세요",
                            emoji: granted ? "🔔" : "⚠️"
                        )
                    }
                } label: {
                    menuRow(icon: "bell.fill", title: "기념일 알림 다시 설정")
                }
                .buttonStyle(.plain)

                Divider().overlay(palette.outline).padding(.leading, 52)

                Button { showSignOutConfirm = true } label: {
                    menuRow(icon: "rectangle.portrait.and.arrow.right", title: "로그아웃", tint: .red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutCard: some View {
        VStack(spacing: 4) {
            Text("OurLog")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textSecondary)
            Text("둘만의 기록을 한 곳에 🐾")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: 조각

    private func row(label: String, value: String, showChevron: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func menuRow(icon: String, title: String, tint: Color? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint ?? palette.primary)
                .frame(width: 28, height: 28)
                .background((tint ?? palette.primary).opacity(0.14), in: .circle)

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(tint ?? palette.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .contentShape(.rect)
    }
}

// MARK: - 테마 고르기

struct ThemePickerCard: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        CuteCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "색깔 테마", systemImage: "paintpalette.fill")

                Text("고른 테마는 둘 다에게 똑같이 적용돼요")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(palette.textSecondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                    ForEach(AppTheme.allCases) { theme in
                        let isSelected = app.theme == theme

                        Button {
                            Task { await app.setTheme(theme) }
                        } label: {
                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Circle().fill(theme.palette.primary).frame(width: 16, height: 16)
                                    Circle().fill(theme.palette.accent).frame(width: 12, height: 12)
                                    Circle().fill(theme.palette.primarySoft).frame(width: 10, height: 10)
                                }

                                Text(theme.displayName)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isSelected ? theme.palette.primarySoft : palette.surfaceAlt,
                                        in: .rect(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(isSelected ? theme.palette.primary : .clear, lineWidth: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 처음 만난 날

private struct StartDateSheet: View {
    @Binding var date: Date

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                VStack(spacing: 16) {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal, 8)

                    Button("저장") {
                        Task { await app.setStartDate(date) }
                        dismiss()
                    }
                    .buttonStyle(.soft)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("처음 만난 날")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 프로필 수정

struct ProfileEditorView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🐣"
    @State private var hasBirthday = false
    @State private var birthday = Date.now

    private let emojiChoices = ["🐣", "🐰", "🐻", "🐱", "🐶", "🦊", "🐨", "🐼", "🐧", "🌷", "⭐️", "🍓"]

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        CuteCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("프로필 이모지")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.textSecondary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                                    ForEach(emojiChoices, id: \.self) { choice in
                                        Button { emoji = choice } label: {
                                            Text(choice)
                                                .font(.system(size: 24))
                                                .frame(width: 50, height: 50)
                                                .background(
                                                    emoji == choice ? palette.primarySoft : palette.surfaceAlt,
                                                    in: .circle
                                                )
                                                .overlay {
                                                    Circle().strokeBorder(
                                                        emoji == choice ? palette.primary : .clear,
                                                        lineWidth: 2
                                                    )
                                                }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        CuteCard {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("이름")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(palette.textSecondary)
                                    TextField("이름", text: $name)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 14)
                                        .background(palette.surfaceAlt, in: .rect(cornerRadius: 14))
                                }

                                Toggle(isOn: $hasBirthday) {
                                    Text("생일 등록")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(palette.textPrimary)
                                }
                                .tint(palette.primary)

                                if hasBirthday {
                                    DatePicker("생일", selection: $birthday, displayedComponents: .date)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                }
                            }
                        }

                        Button("저장") {
                            Task {
                                await app.updateMyProfile(
                                    name: name.trimmingCharacters(in: .whitespaces),
                                    emoji: emoji,
                                    birthday: hasBirthday ? birthday : nil
                                )
                                await app.refreshNotifications()
                            }
                            dismiss()
                        }
                        .buttonStyle(.soft)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("프로필")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            .onAppear {
                name = app.me?.displayName ?? ""
                emoji = app.me?.emoji ?? "🐣"
                if let existing = app.me?.birthday {
                    hasBirthday = true
                    birthday = existing
                }
            }
        }
    }
}
