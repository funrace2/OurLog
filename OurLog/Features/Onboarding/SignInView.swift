//
//  SignInView.swift
//  OurLog
//
//  첫 화면. 로그인만 한다. 커플 연결은 다음 단계에서.
//

import SwiftUI

struct SignInView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    @State private var isWorking = false

    var body: some View {
        ZStack {
            CuteBackground()

            VStack(spacing: 0) {
                Spacer()

                CatPortrait(stage: .kitten, size: 190)

                Text("OurLog")
                    .font(.hand(46, bold: true))
                    .foregroundStyle(palette.primary)
                    .padding(.top, 4)

                Text("둘만의 기록을 한 곳에")
                    .font(.hand(20))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 6)

                Spacer()

                VStack(spacing: 12) {
                    ForEach(Highlight.all) { highlight in
                        HStack(spacing: 12) {
                            Image(systemName: highlight.symbol)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(palette.primary)
                                .sketchCircle(fill: palette.primarySoft, seed: 368, size: 32)

                            Text(highlight.text)
                                .font(.hand(19))
                                .foregroundStyle(palette.textPrimary)

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 36)

                Spacer()

                Button {
                    Task {
                        isWorking = true
                        await app.signIn()
                        isWorking = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isWorking {
                            ProgressView().tint(palette.paper)
                        }
                        Text(signInTitle)
                    }
                }
                .buttonStyle(.soft)
                .disabled(isWorking)
                .padding(.horizontal, 28)

                Text("로그인하면 둘 사이의 기록이 안전하게 보관돼요")
                    .font(.hand(15))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
            }
        }
    }
}

private struct Highlight: Identifiable {
    let id = UUID()
    let symbol: String
    let text: String

    static let all: [Highlight] = [
        .init(symbol: "heart.fill", text: "디데이와 기념일을 놓치지 않게"),
        .init(symbol: "mappin.and.ellipse", text: "함께 간 곳, 가고 싶은 곳 모아두기"),
        .init(symbol: "book.closed.fill", text: "사진과 함께 쓰는 데이트 일기"),
        .init(symbol: "pawprint.fill", text: "둘이 같이 키우는 고양이"),
    ]
}

private extension SignInView {
    var signInTitle: String {
        if AppEnvironment.useAppleSignIn { return "Apple로 시작하기" }
        return AppEnvironment.usesFirebase ? "Google로 시작하기" : "시작하기"
    }
}

#Preview {
    SignInView()
        .environment(AppEnvironment.makeAppState())
        .environment(\.palette, AppTheme.default.palette)
}
