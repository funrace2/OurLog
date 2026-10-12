//
//  CuteComponents.swift
//  OurLog
//
//  아기자기한 느낌을 만드는 공용 UI 조각들.
//  둥근 모서리 + 부드러운 그림자 + 파스텔 톤을 한 군데에 모아 둔다.
//

import SwiftUI

// MARK: - 카드

/// 앱 전반에서 쓰는 기본 카드. 모서리가 크게 둥글고 그림자가 아주 옅다.
struct CuteCard<Content: View>: View {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 24
    @ViewBuilder var content: Content

    @Environment(\.palette) private var palette

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(palette.outline, lineWidth: 1)
            }
            .shadow(color: palette.primary.opacity(0.10), radius: 12, y: 4)
    }
}

// MARK: - 버튼

/// 누르면 살짝 쪼그라드는 말랑한 버튼.
struct SoftButtonStyle: ButtonStyle {
    enum Kind { case filled, tinted, plain }

    var kind: Kind = .filled
    var cornerRadius: CGFloat = 18

    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: kind == .plain ? nil : .infinity)
            .background(background, in: .rect(cornerRadius: cornerRadius))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .filled: .white
        case .tinted, .plain: palette.primary
        }
    }

    private var background: Color {
        switch kind {
        case .filled: palette.primary
        case .tinted: palette.primarySoft
        case .plain: .clear
        }
    }
}

extension ButtonStyle where Self == SoftButtonStyle {
    static var soft: SoftButtonStyle { SoftButtonStyle() }
    static var softTinted: SoftButtonStyle { SoftButtonStyle(kind: .tinted) }
    static var softPlain: SoftButtonStyle { SoftButtonStyle(kind: .plain) }
}

// MARK: - 섹션 헤더

struct SectionHeader: View {
    let title: String
    var systemImage: String?
    var action: (title: String, handler: () -> Void)?

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.primary)
            }
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textPrimary)

            Spacer()

            if let action {
                Button(action.title, action: action.handler)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}

// MARK: - 칩

struct Chip: View {
    let text: String
    var systemImage: String?
    var tint: Color?

    @Environment(\.palette) private var palette

    var body: some View {
        let color = tint ?? palette.primary
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 11, weight: .bold))
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(color.opacity(0.14), in: .capsule)
    }
}

// MARK: - 빈 상태

struct EmptyStateView: View {
    let emoji: String
    let title: String
    let message: String

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 44))
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
            Text(message)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - 애정도 바

/// 고양이 성장 진행도를 보여주는 하트 게이지.
struct AffectionBar: View {
    /// 0...1
    let progress: Double

    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.primarySoft)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [palette.primary, palette.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
    }
}

// MARK: - 배경

/// 화면 전체에 까는 파스텔 배경. 위쪽에 아주 옅은 그라데이션을 얹는다.
struct CuteBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        palette.background
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [palette.primary.opacity(0.14), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()
    }
}

// MARK: - 편의 확장

extension View {
    /// 화면 루트에 배경 + 테마를 한 번에 적용한다.
    func cuteScreen() -> some View {
        self.background(CuteBackground())
    }
}
