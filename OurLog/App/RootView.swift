//
//  RootView.swift
//  OurLog
//
//  로그인 상태에 따라 온보딩 / 커플 연결 / 메인 탭을 가른다.
//

import SwiftUI

struct RootView: View {
    @State private var app = AppEnvironment.makeAppState()

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

struct MainTabView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        TabView {
            Tab("홈", systemImage: "house") {
                HomeView()
            }
            Tab("지도", systemImage: "map") {
                PlacesMapView()
            }
            Tab("캘린더", systemImage: "calendar") {
                SharedCalendarView()
            }
            Tab("일기", systemImage: "book.closed") {
                DiaryListView()
            }
            Tab("고양이", systemImage: "pawprint") {
                CatRoomView()
            }
        }
        .tint(palette.primary)
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
