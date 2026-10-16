//
//  Theme.swift
//  OurLog
//
//  종이 & 잉크 디자인 토큰 (SpendLog 와 같은 손그림 스타일).
//  테마를 고르면 종이 색과 펜 색이 함께 바뀌고, 둘 모두에게 똑같이 적용된다.
//  잉크(글자·테두리)는 어느 종이에서나 같은 짙은 갈색이라 손글씨 느낌이 유지된다.
//

import SwiftUI

// MARK: - 팔레트

nonisolated struct ThemePalette {
    /// 화면 바탕 종이
    let paper: Color
    /// 상자 안쪽 종이 (조금 더 밝다)
    let card: Color
    /// 입력칸처럼 한 단계 들어간 종이
    let paperDeep: Color
    /// 강조 펜 (디데이 숫자, 선택 표시, 버튼)
    let pen: Color
    /// 펜 색을 옅게 깐 형광펜
    let penSoft: Color

    // 모든 테마 공통
    var ink: Color { Theme.ink }
    var inkSoft: Color { Theme.inkSoft }

    // 기존 화면 코드가 쓰는 이름 → 종이·잉크로 연결
    var background: Color { paper }
    var surface: Color { card }
    var surfaceAlt: Color { paperDeep }
    var primary: Color { pen }
    var primarySoft: Color { penSoft }
    var accent: Color { pen }
    var textPrimary: Color { ink }
    var textSecondary: Color { inkSoft }
    var outline: Color { ink.opacity(0.28) }
}

nonisolated enum Theme {
    static let ink = Color(hex: 0x26231C)
    static let inkSoft = Color(hex: 0x6E695C)
    static let redPen = Color(hex: 0xC0483A)    // 일요일
    static let bluePen = Color(hex: 0x3C6491)   // 토요일

    /// 나눔손글씨 다시 시작해. 번들에 없으면 시스템 글꼴로 대체된다.
    static let fontName = "NanumDaSiSiJagHae"
}

extension Font {
    /// 손글씨. 이 글꼴은 같은 크기에서 시스템 글꼴보다 작게 보여서 숫자를 넉넉히 준다.
    static func hand(_ size: CGFloat, bold: Bool = false) -> Font {
        let font = Font.custom(Theme.fontName, size: size)
        return bold ? font.weight(.bold) : font
    }
}

// MARK: - 테마

nonisolated enum AppTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    // rawValue 는 저장된 데이터와 맞추기 위해 예전 이름을 그대로 쓴다.
    case butter     // 크림 종이 (기본, SpendLog 와 같은 색)
    case peach      // 벚꽃 종이
    case mint       // 민트 종이
    case sky        // 하늘 종이
    case lavender   // 라벤더 종이
    case cocoa      // 코코아 종이

    static let `default`: AppTheme = .butter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .butter: "크림"
        case .peach: "벚꽃"
        case .mint: "민트"
        case .sky: "하늘"
        case .lavender: "라벤더"
        case .cocoa: "코코아"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .butter:
            ThemePalette(paper: Color(hex: 0xF3EEE1), card: Color(hex: 0xFCFAF2), paperDeep: Color(hex: 0xEAE3D2),
                         pen: Color(hex: 0xC0483A), penSoft: Color(hex: 0xF2DDD3))
        case .peach:
            ThemePalette(paper: Color(hex: 0xF7E7E6), card: Color(hex: 0xFFF7F6), paperDeep: Color(hex: 0xEFD7D6),
                         pen: Color(hex: 0xC4506A), penSoft: Color(hex: 0xF4D3DA))
        case .mint:
            ThemePalette(paper: Color(hex: 0xE4EFE6), card: Color(hex: 0xF6FBF6), paperDeep: Color(hex: 0xD4E5D8),
                         pen: Color(hex: 0x3B8466), penSoft: Color(hex: 0xCFE6DA))
        case .sky:
            ThemePalette(paper: Color(hex: 0xE4ECF4), card: Color(hex: 0xF6F9FC), paperDeep: Color(hex: 0xD3DEEB),
                         pen: Color(hex: 0x3C6491), penSoft: Color(hex: 0xD3DEEC))
        case .lavender:
            ThemePalette(paper: Color(hex: 0xEBE6F2), card: Color(hex: 0xF9F6FC), paperDeep: Color(hex: 0xDDD5EA),
                         pen: Color(hex: 0x76589F), penSoft: Color(hex: 0xE0D6EE))
        case .cocoa:
            ThemePalette(paper: Color(hex: 0xEFE5D9), card: Color(hex: 0xFBF6F0), paperDeep: Color(hex: 0xE2D4C3),
                         pen: Color(hex: 0x8A5A3C), penSoft: Color(hex: 0xEAD8C8))
        }
    }
}

// MARK: - Environment

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = AppTheme.default.palette
}

extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - 시드

/// 손그림 도형의 떨림 모양을 정하는 시드. 같은 시드면 늘 같은 모양으로 그려져 다시 그려도 떨리지 않는다.
nonisolated func sketchSeed(_ text: String, salt: UInt64 = 0) -> UInt64 {
    // FNV-1a — 실행할 때마다 바뀌는 hashValue 대신 고정된 값을 쓴다
    var h: UInt64 = 0xcbf29ce484222325
    for b in text.utf8 {
        h ^= UInt64(b)
        h = h &* 0x100000001b3
    }
    return h ^ salt
}
