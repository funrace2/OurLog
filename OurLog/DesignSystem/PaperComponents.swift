//
//  PaperComponents.swift
//  OurLog
//
//  종이 위에 잉크로 그린 공용 UI 조각들.
//  (예전 이름 CuteCard / SoftButtonStyle 을 그대로 써서 화면 코드는 손대지 않아도 된다)
//

import SwiftUI

// MARK: - 상자

/// 손그림 테두리 상자. 같은 자리의 상자는 늘 같은 모양으로 떨리도록
/// 호출한 파일·줄로 시드를 만든다. 목록처럼 같은 줄에서 여러 개 그릴 땐 seed 를 직접 준다.
struct CuteCard<Content: View>: View {
    var padding: CGFloat
    var seed: UInt64
    var fill: Color?
    @ViewBuilder var content: Content

    @Environment(\.palette) private var palette

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 0,      // 예전 호출부 호환용 (손그림 상자에는 모서리 둥글기가 없다)
        seed: UInt64? = nil,
        fill: Color? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.seed = seed ?? sketchSeed("\(file)", salt: UInt64(line))
        self.fill = fill
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sketchBox(seed: seed, fill: fill ?? palette.card)
    }
}

// MARK: - 버튼

struct SoftButtonStyle: ButtonStyle {
    enum Kind { case filled, tinted, plain }
    var kind: Kind = .filled

    func makeBody(configuration: Configuration) -> some View {
        SketchButtonBody(configuration: configuration, kind: kind)
    }
}

private struct SketchButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: SoftButtonStyle.Kind

    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Group {
            switch kind {
            case .filled:
                configuration.label
                    .font(.hand(23, bold: true))
                    .foregroundStyle(palette.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .sketchBox(seed: 7, fill: palette.ink)
            case .tinted:
                configuration.label
                    .font(.hand(21, bold: true))
                    .foregroundStyle(palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .sketchBox(seed: 11, fill: palette.penSoft)
            case .plain:
                configuration.label
                    .font(.hand(19, bold: true))
                    .foregroundStyle(palette.pen)
                    .padding(.vertical, 6)
            }
        }
        .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

extension ButtonStyle where Self == SoftButtonStyle {
    static var soft: SoftButtonStyle { SoftButtonStyle() }
    static var softTinted: SoftButtonStyle { SoftButtonStyle(kind: .tinted) }
    static var softPlain: SoftButtonStyle { SoftButtonStyle(kind: .plain) }
}

// MARK: - 섹션 제목

struct SectionHeader: View {
    let title: String
    var systemImage: String?
    var action: (title: String, handler: () -> Void)?

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.hand(25, bold: true))
                .foregroundStyle(palette.ink)
                .background(alignment: .bottom) {
                    // 형광펜으로 밑줄 긋듯
                    palette.penSoft.frame(height: 9).offset(y: -3)
                }

            Spacer()

            if let action {
                Button(action.title, action: action.handler)
                    .font(.hand(19))
                    .foregroundStyle(palette.inkSoft)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - 칩

struct Chip: View {
    let text: String
    var systemImage: String?
    var tint: Color?

    @Environment(\.palette) private var palette

    var body: some View {
        let color = tint ?? palette.pen
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
            Text(text).font(.hand(16, bold: true))
        }
        .foregroundStyle(color)
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .sketchBox(seed: sketchSeed(text), fill: palette.card, stroke: color, roughness: 1.1, lineWidth: 1.4)
    }
}

// MARK: - 빈 상태

struct EmptyStateView: View {
    let title: String
    let message: String

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 6) {
            PixelSpriteView(sprite: CatSprites.kittenIdle)
                .frame(width: 64, height: 64)
                .padding(.bottom, 4)
            Text(title)
                .font(.hand(22, bold: true))
                .foregroundStyle(palette.ink)
            Text(message)
                .font(.hand(17))
                .foregroundStyle(palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - 애정도 게이지

struct AffectionBar: View {
    /// 0...1
    let progress: Double

    @Environment(\.palette) private var palette

    var body: some View {
        let shape = SketchRectangle(seed: 41, roughness: 1.2)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                shape.fill(palette.card)
                Rectangle()
                    .fill(palette.pen.opacity(0.75))
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
                    .mask(shape)
                shape.stroke(palette.ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: 18)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
    }
}

// MARK: - 구분선

struct SketchDivider: View {
    var seed: UInt64 = 3

    var body: some View {
        SketchLine(seed: seed)
            .stroke(Theme.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            .frame(height: 8)
    }
}

// MARK: - 고르기 (세그먼트 대신)

struct SketchPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isOn = option.value == selection
                Button {
                    withAnimation(.snappy) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.hand(19, bold: isOn))
                        .foregroundStyle(isOn ? palette.ink : palette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if isOn {
                                SketchRectangle(seed: UInt64(index) &+ 90, roughness: 1.3)
                                    .fill(palette.penSoft)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .sketchBox(seed: 88, fill: palette.card)
    }
}

// MARK: - 입력칸

extension View {
    /// 텍스트 입력칸을 손그림 상자에 넣는다.
    func sketchField(file: StaticString = #fileID, line: UInt = #line) -> some View {
        modifier(SketchField(seed: sketchSeed("\(file)", salt: UInt64(line) &+ 500)))
    }

    /// 손그림 동그라미 배경 (아이콘·이모지 받침).
    func sketchCircle(fill: Color, seed: UInt64 = 21, size: CGFloat) -> some View {
        frame(width: size, height: size)
            .background(SketchCircle(seed: seed).fill(fill))
            .overlay(SketchCircle(seed: seed).stroke(Theme.ink, lineWidth: 1.6))
    }
}

private struct SketchField: ViewModifier {
    let seed: UInt64
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .sketchBox(seed: seed, fill: palette.card, roughness: 1.3, lineWidth: 1.6)
    }
}

// MARK: - 배경

/// 화면 전체에 까는 종이. 내비게이션 바·탭 바도 같은 종이색으로 맞춘다.
struct CuteBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        palette.paper
            .ignoresSafeArea()
            .toolbarBackground(palette.paper, for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
    }
}

extension View {
    func cuteScreen() -> some View {
        background(CuteBackground())
    }
}
