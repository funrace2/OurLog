//
//  CoupleSetupView.swift
//  OurLog
//
//  커플 만들기 / 초대코드로 연결하기.
//

import SwiftUI

struct CoupleSetupView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case create, join
        var id: String { rawValue }
        var title: String {
            switch self {
            case .create: "새로 시작하기"
            case .join: "초대코드 입력"
            }
        }
    }

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    @State private var mode: Mode = .create
    @State private var myName = ""
    @State private var startDate = Date.now
    @State private var inviteCode = ""
    @State private var isWorking = false

    var body: some View {
        ZStack {
            CuteBackground()

            ScrollView {
                VStack(spacing: 20) {
                    header

                    SketchPicker(selection: $mode, options: Mode.allCases.map { ($0, $0.title) })

                    CuteCard {
                        VStack(alignment: .leading, spacing: 18) {
                            field("내 이름", placeholder: "상대에게 보여질 이름", text: $myName)

                            if mode == .create {
                                VStack(alignment: .leading, spacing: 8) {
                                    label("우리가 처음 만난 날")
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                }
                                Text("이 날짜를 기준으로 디데이와 100일·주년 기념일이 자동으로 만들어져요.")
                                    .font(.hand(16))
                                    .foregroundStyle(palette.textSecondary)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    label("초대코드")
                                    TextField("ABC123", text: $inviteCode)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(.hand(30, bold: true))
                                        .kerning(6)
                                        .multilineTextAlignment(.center)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity)
                                        .sketchBox(seed: 375, fill: palette.surfaceAlt, roughness: 1.3, lineWidth: 1.6)
                                        .onChange(of: inviteCode) { _, newValue in
                                            inviteCode = String(InviteCode.normalize(newValue).prefix(6))
                                        }
                                }
                                Text("상대방 설정 화면에 있는 6자리 코드를 입력해 주세요.")
                                    .font(.hand(16))
                                    .foregroundStyle(palette.textSecondary)
                            }
                        }
                    }

                    Button(mode == .create ? "우리 공간 만들기" : "연결하기") {
                        Task { await submit() }
                    }
                    .buttonStyle(.soft)
                    .disabled(!canSubmit || isWorking)

                    Button("다른 계정으로 로그인") { app.signOut() }
                        .buttonStyle(.softPlain)
                }
                .padding(20)
            }
        }
        .onAppear {
            if myName.isEmpty, let name = app.user?.displayName {
                myName = name
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            CatPortrait(stage: .egg, size: 140)
            Text("둘을 연결해 주세요")
                .font(.hand(30, bold: true))
                .foregroundStyle(palette.textPrimary)
            Text("한 명이 공간을 만들고, 다른 한 명이 초대코드로 들어와요")
                .font(.hand(18))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.hand(18, bold: true))
            .foregroundStyle(palette.textSecondary)
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            label(title)
            TextField(placeholder, text: text)
                .font(.hand(22))
                .sketchField()
        }
    }

    private var canSubmit: Bool {
        let hasName = !myName.trimmingCharacters(in: .whitespaces).isEmpty
        return switch mode {
        case .create: hasName
        case .join: hasName && inviteCode.count == 6
        }
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }

        let name = myName.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create:
            await app.createCouple(myName: name, startDate: startDate)
        case .join:
            await app.joinCouple(code: inviteCode, myName: name)
        }
    }
}

#Preview {
    CoupleSetupView()
        .environment(AppEnvironment.makeAppState())
        .environment(\.palette, AppTheme.default.palette)
}
