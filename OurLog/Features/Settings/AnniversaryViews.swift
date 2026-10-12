//
//  AnniversaryViews.swift
//  OurLog
//
//  기념일 목록과 추가/수정.
//  100일·주년은 처음 만난 날로부터 자동으로 만들어지고, 여기서는 직접 등록한 것만 관리한다.
//

import SwiftUI

// MARK: - 목록

struct AnniversaryListView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var showEditor = false
    @State private var editing: Anniversary?

    private var custom: [Anniversary] {
        (app.snapshot?.anniversaries ?? []).sorted { $0.nextOccurrence < $1.nextOccurrence }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 10) {
                            SectionHeader(title: "직접 등록한 기념일", systemImage: "gift.fill")

                            if custom.isEmpty {
                                CuteCard {
                                    EmptyStateView(
                                        title: "등록된 기념일이 없어요",
                                        message: "첫 여행, 프러포즈한 날처럼 둘만의 날을 더해보세요"
                                    )
                                }
                            } else {
                                CuteCard(padding: 0) {
                                    VStack(spacing: 0) {
                                        ForEach(Array(custom.enumerated()), id: \.element.id) { index, anniversary in
                                            Button {
                                                editing = anniversary
                                                showEditor = true
                                            } label: {
                                                AnniversaryRow(anniversary: anniversary)
                                            }
                                            .buttonStyle(.plain)

                                            if index < custom.count - 1 {
                                                SketchDivider().padding(.leading, 56)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        VStack(spacing: 10) {
                            SectionHeader(title: "자동으로 챙겨요", systemImage: "sparkles")

                            CuteCard(padding: 0) {
                                VStack(spacing: 0) {
                                    let auto = app.upcomingAnniversaries
                                        .filter { $0.kind != .custom }
                                        .prefix(6)

                                    ForEach(Array(auto.enumerated()), id: \.element.id) { index, anniversary in
                                        AnniversaryRow(anniversary: anniversary)
                                        if index < auto.count - 1 {
                                            SketchDivider().padding(.leading, 56)
                                        }
                                    }
                                }
                            }

                            Text("100일 단위와 주년, 생일은 따로 등록하지 않아도 자동으로 올라와요")
                                .font(.hand(15))
                                .foregroundStyle(palette.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("기념일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                AnniversaryEditorView(anniversary: editing)
            }
        }
    }
}

// MARK: - 추가 / 수정

struct AnniversaryEditorView: View {
    /// nil 이면 새 기념일
    var anniversary: Anniversary?

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date.now
    @State private var emoji = "🎀"
    @State private var repeatsYearly = true
    @State private var notifyDaysBefore: Set<Int> = [0, 1]
    @State private var showDeleteConfirm = false

    private let emojiChoices = ["🎀", "💗", "🎉", "🌸", "✨", "🍰", "🎁", "💍", "🧸", "🌙"]
    private let notifyOptions = [0, 1, 3, 7, 30]

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        CuteCard {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 8) {
                                    fieldLabel("기념일 이름")
                                    TextField("첫 여행, 프러포즈한 날…", text: $title)
                                        .font(.hand(22))
                                        .sketchField()
                                }

                                DatePicker("날짜", selection: $date, displayedComponents: .date)
                                    .font(.hand(20))

                                Toggle(isOn: $repeatsYearly) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("매년 반복")
                                            .font(.hand(20, bold: true))
                                            .foregroundStyle(palette.textPrimary)
                                        Text("생일처럼 해마다 돌아오는 날이면 켜주세요")
                                            .font(.hand(15))
                                            .foregroundStyle(palette.textSecondary)
                                    }
                                }
                                .tint(palette.primary)
                            }
                        }

                        CuteCard {
                            VStack(alignment: .leading, spacing: 10) {
                                fieldLabel("이모지")

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 8) {
                                    ForEach(emojiChoices, id: \.self) { choice in
                                        Button { emoji = choice } label: {
                                            Text(choice)
                                                .font(.system(size: 22))
                                                .sketchCircle(
                                                    fill: emoji == choice ? palette.primarySoft : palette.card,
                                                    seed: sketchSeed(choice),
                                                    size: 46
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        CuteCard {
                            VStack(alignment: .leading, spacing: 10) {
                                fieldLabel("알림")

                                Text("선택한 날짜의 오전 9시에 알려드려요")
                                    .font(.hand(15))
                                    .foregroundStyle(palette.textSecondary)

                                HStack(spacing: 8) {
                                    ForEach(notifyOptions, id: \.self) { days in
                                        let isOn = notifyDaysBefore.contains(days)

                                        Button {
                                            if isOn { notifyDaysBefore.remove(days) }
                                            else { notifyDaysBefore.insert(days) }
                                        } label: {
                                            Text(days == 0 ? "당일" : "\(days)일 전")
                                                .font(.hand(16, bold: true))
                                                .foregroundStyle(isOn ? palette.ink : palette.textSecondary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 7)
                                                .sketchBox(
                                                    seed: UInt64(days) &+ 70,
                                                    fill: isOn ? palette.primarySoft : palette.card,
                                                    roughness: 1.2,
                                                    lineWidth: isOn ? 2 : 1.2
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Button(anniversary == nil ? "추가하기" : "수정하기") { save() }
                            .buttonStyle(.soft)
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                        if anniversary != nil {
                            Button("기념일 삭제", role: .destructive) { showDeleteConfirm = true }
                                .buttonStyle(.softPlain)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(anniversary == nil ? "새 기념일" : "기념일 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            .confirmationDialog("이 기념일을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    if let anniversary { Task { await app.deleteAnniversary(id: anniversary.id) } }
                    dismiss()
                }
            }
            .onAppear(perform: load)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.hand(18, bold: true))
            .foregroundStyle(palette.textSecondary)
    }

    private func load() {
        guard let anniversary else { return }
        title = anniversary.title
        date = anniversary.date
        emoji = anniversary.emoji
        repeatsYearly = anniversary.repeatsYearly
        notifyDaysBefore = Set(anniversary.notifyDaysBefore)
    }

    private func save() {
        let updated = Anniversary(
            id: anniversary?.id ?? UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespaces),
            date: date,
            kind: .custom,
            repeatsYearly: repeatsYearly,
            notifyDaysBefore: notifyDaysBefore.sorted(),
            emoji: emoji
        )

        Task { await app.addAnniversary(updated) }
        dismiss()
    }
}
