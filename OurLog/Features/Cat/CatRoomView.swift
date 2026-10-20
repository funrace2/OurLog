//
//  CatRoomView.swift
//  OurLog
//
//  고양이가 사는 방. 쓰다듬고, 꾸미고, 성장 상태를 본다.
//

import SwiftUI

struct CatRoomView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    @State private var isPetting = false
    @State private var showDecorate = false
    @State private var showRename = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        room
                        statusCard
                        howToGrow
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .paperTitle("우리 고양이")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDecorate = true } label: {
                        Image(systemName: "wand.and.stars")
                    }
                }
            }
            .sheet(isPresented: $showDecorate) { DecorateView() }
            .alert("이름 지어주기", isPresented: $showRename) {
                TextField("고양이 이름", text: $newName)
                Button("저장") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    Task { await app.renameCat(trimmed) }
                }
                Button("취소", role: .cancel) {}
            }
        }
    }

    // MARK: 방

    private var room: some View {
        PixelRoomView(
            stage: app.cat.stage,
            accessories: app.equippedAccessories,
            placedItems: app.placedRoomItems,
            isBeingPetted: isPetting
        )
        .contentShape(.rect)
        .onTapGesture { pet() }
        .overlay(alignment: .bottomTrailing) {
            Text("톡 누르면 쓰다듬어요")
                .font(.hand(15))
                .foregroundStyle(palette.textSecondary)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .sketchBox(seed: 228, fill: palette.surface.opacity(0.9), roughness: 1.1, lineWidth: 1.4)
                .padding(10)
        }
        .clipShape(.rect(cornerRadius: 12))
    }

    private func pet() {
        isPetting = true
        Task {
            await app.gainAffection(.pet, silent: true)
            try? await Task.sleep(for: .milliseconds(700))
            isPetting = false
        }
    }

    // MARK: 상태 카드

    private var statusCard: some View {
        CuteCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.cat.name)
                            .font(.hand(26, bold: true))
                            .foregroundStyle(palette.textPrimary)
                        Text("\(app.cat.stage.rawValue)단계 · \(app.cat.stage.displayName)")
                            .font(.hand(18))
                            .foregroundStyle(palette.textSecondary)
                    }

                    Spacer()

                    Button {
                        newName = app.cat.name
                        showRename = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.primary)
                            .sketchCircle(fill: palette.primarySoft, seed: 221, size: 34)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("애정도 \(app.cat.affection)")
                            .font(.hand(18, bold: true))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        if let next = app.cat.stage.next {
                            Text("\(next.displayName)까지 \(app.cat.affectionToNextStage ?? 0)")
                                .font(.hand(16))
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    AffectionBar(progress: app.cat.progressToNextStage)
                }

                stageTrack
            }
        }
    }

    /// 6단계를 점으로 나열해 지금 어디쯤인지 보여준다.
    private var stageTrack: some View {
        let stages = CatStage.allCases
        let current = app.cat.stage

        return GeometryReader { geo in
            let cell = geo.size.width / CGFloat(stages.count)
            let centerX = { (index: Int) in cell * (CGFloat(index) + 0.5) }
            let currentIndex = stages.firstIndex(of: current) ?? 0
            let y = geo.size.height / 2

            ZStack(alignment: .topLeading) {
                // 전체 길 (첫 단계 중심 → 마지막 단계 중심)
                SketchLine(seed: 501)
                    .stroke(palette.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .frame(width: centerX(stages.count - 1) - centerX(0), height: 10)
                    .position(x: (centerX(0) + centerX(stages.count - 1)) / 2, y: y)

                // 지나온 길
                if currentIndex > 0 {
                    SketchLine(seed: 502)
                        .stroke(palette.pen, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                        .frame(width: centerX(currentIndex) - centerX(0), height: 10)
                        .position(x: (centerX(0) + centerX(currentIndex)) / 2, y: y)
                }

                ForEach(Array(stages.enumerated()), id: \.element) { index, stage in
                    StageDot(number: stage.rawValue, state: index < currentIndex ? .passed : (index == currentIndex ? .current : .upcoming))
                        .position(x: centerX(index), y: y)
                }
            }
        }
        .frame(height: 36)
        .accessibilityElement()
        .accessibilityLabel("6단계 중 \(current.rawValue)단계")
    }

    // MARK: 키우는 법

    private var howToGrow: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "이렇게 자라요", systemImage: "heart.circle.fill")

            CuteCard(padding: 0) {
                VStack(spacing: 0) {
                    let actions: [AffectionAction] = [
                        .addDiary, .visitPlace, .savePlace, .addEvent, .dailyCheckIn, .pet,
                    ]
                    ForEach(Array(actions.enumerated()), id: \.element.rawValue) { index, action in
                        let used = app.cat.usedToday(action)
                        let done = used >= action.dailyLimit
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(action.label)
                                    .font(.hand(19))
                                    .foregroundStyle(done ? palette.textSecondary : palette.textPrimary)
                                Text("하루 \(action.dailyLimit)번 · 오늘 \(used)/\(action.dailyLimit)")
                                    .font(.hand(14))
                                    .foregroundStyle(palette.textSecondary)
                            }
                            Spacer()
                            Text(done ? "오늘 끝" : "+\(action.points)")
                                .font(.hand(19, bold: true))
                                .foregroundStyle(done ? palette.textSecondary : palette.accent)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)

                        if index < actions.count - 1 {
                            SketchDivider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 진화 축하

struct EvolutionCelebrationView: View {
    let stage: CatStage

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false

    var body: some View {
        ZStack {
            CuteBackground()

            VStack(spacing: 18) {
                Spacer()

                Text("진화했어요!")
                    .font(.hand(20, bold: true))
                    .foregroundStyle(palette.textSecondary)
                    .opacity(appeared ? 1 : 0)

                Text(stage.displayName)
                    .font(.hand(43, bold: true))
                    .foregroundStyle(palette.primary)
                    .scaleEffect(appeared ? 1 : 0.6)

                CatPortrait(stage: stage, accessories: app.equippedAccessories, size: 220)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -18))

                Text(stage.tagline)
                    .font(.hand(19))
                    .foregroundStyle(palette.textSecondary)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                Button("고마워 🐾") { dismiss() }
                    .buttonStyle(.soft)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { appeared = true }
        }
    }
}

#Preview {
    CatRoomView()
        .environment(AppEnvironment.makeAppState())
        .environment(\.palette, AppTheme.default.palette)
}

// MARK: - 단계 점

private struct StageDot: View {
    enum State { case passed, current, upcoming }

    let number: Int
    let state: State

    @Environment(\.palette) private var palette

    var body: some View {
        let size: CGFloat = state == .current ? 32 : 24
        let seed = UInt64(number) &+ 610

        Text("\(number)")
            .font(.hand(state == .current ? 20 : 16, bold: state != .upcoming))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(SketchCircle(seed: seed, roughness: 1.2).fill(fill))
            .overlay(
                SketchCircle(seed: seed, roughness: 1.2)
                    .stroke(stroke, lineWidth: state == .current ? 2.2 : 1.5)
            )
    }

    private var fill: Color {
        switch state {
        case .passed: palette.penSoft
        case .current: palette.pen
        case .upcoming: palette.card
        }
    }

    private var foreground: Color {
        switch state {
        case .passed: palette.ink
        case .current: palette.paper
        case .upcoming: palette.inkSoft.opacity(0.6)
        }
    }

    private var stroke: Color {
        switch state {
        case .passed, .current: palette.ink
        case .upcoming: palette.ink.opacity(0.3)
        }
    }
}
