//
//  RootView.swift
//  OurLog
//
//  로그인 상태에 따라 온보딩 / 커플 연결 / 메인 탭을 가른다.
//

import SwiftUI

struct RootView: View {
    @State private var app = AppEnvironment.makeAppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            switch app.phase {
            case .loading:
                LoadingScreen()
            case .signedOut:
                SignInView()
            case .needsCouple:
                CoupleSetupView()
            case .ready:
                MainTabView()
            }
        }
        // 입력칸 바깥을 탭하면 키보드를 닫는다 (앱 창에 한 번 걸어서 시트까지 적용)
        .background(KeyboardDismissOnTap().allowsHitTesting(false))
        .environment(app)
        .environment(\.palette, app.palette)
        .tint(app.palette.ink)
        // SpendLog 처럼 종이 느낌을 지키려고 다크 모드를 따르지 않는다
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.3), value: app.phase)
        .overlay(alignment: .top) { ToastView(toast: app.toast) }
        .fullScreenCover(item: Binding(
            get: { app.evolutionToCelebrate.map { EvolutionEvent(stage: $0) } },
            set: { if $0 == nil { app.evolutionToCelebrate = nil } }
        )) { event in
            EvolutionCelebrationView(stage: event.stage)
                .environment(app)
                .environment(\.palette, app.palette)
        }
        .alert(
            "잠깐만요",
            isPresented: Binding(
                get: { app.errorMessage != nil },
                set: { if !$0 { app.errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(app.errorMessage ?? "")
        }
        .task { await app.bootstrap() }
        // 백그라운드에 둔 채 날짜가 바뀌어도, 다시 열면 그날 출석이 된다
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await app.checkInIfNeeded() }
            }
        }
        .onChange(of: app.toast) { _, newValue in
            // 토스트는 잠깐 떴다가 알아서 사라진다.
            guard let newValue else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                if app.toast?.id == newValue.id {
                    withAnimation { app.toast = nil }
                }
            }
        }
    }
}

/// fullScreenCover(item:) 에 넣기 위한 래퍼
private struct EvolutionEvent: Identifiable {
    let stage: CatStage
    var id: Int { stage.rawValue }
}

// MARK: - 로딩

private struct LoadingScreen: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            CuteBackground()
            VStack(spacing: 10) {
                CatPortrait(stage: .egg, size: 110)
                Text("OurLog")
                    .font(.hand(36, bold: true))
                    .foregroundStyle(palette.ink)
            }
        }
    }
}

// MARK: - 메인 탭

enum AppTab: Hashable {
    case home, map, calendar, diary, cat
}

extension EnvironmentValues {
    /// 다른 탭으로 넘어가기 (홈의 고양이 카드처럼 탭 사이를 잇는 곳에서 쓴다)
    @Entry var selectTab: (AppTab) -> Void = { _ in }
}

struct MainTabView: View {
    @Environment(\.palette) private var palette
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("홈", systemImage: "house", value: .home) {
                HomeView()
            }
            Tab("지도", systemImage: "map", value: .map) {
                PlacesMapView()
            }
            Tab("캘린더", systemImage: "calendar", value: .calendar) {
                SharedCalendarView()
            }
            Tab("일기", systemImage: "book.closed", value: .diary) {
                DiaryListView()
            }
            Tab("고양이", systemImage: "pawprint", value: .cat) {
                CatRoomView()
            }
        }
        .tint(palette.primary)
        .environment(\.selectTab) { selection = $0 }
    }
}

// MARK: - 토스트

struct ToastView: View {
    let toast: Toast?

    @Environment(\.palette) private var palette

    var body: some View {
        if let toast {
            HStack(spacing: 8) {
                Text(toast.text)
                    .font(.hand(19, bold: true))
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .sketchBox(seed: 207, fill: palette.surface, roughness: 1.1, lineWidth: 1.4)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .id(toast.id)
        }
    }
}

#Preview {
    RootView()
}
