//
//  Theme.swift
//  OurLog
//
//  앱 전체 색깔 테마. 사용자가 설정에서 고르면 두 사람 모두에게 적용된다.
//

import SwiftUI

// MARK: - 팔레트

nonisolated struct ThemePalette {
    /// 버튼·강조 요소의 주 색상
    let primary: Color
    /// primary 를 연하게 깐 배경 (뱃지, 칩)
    let primarySoft: Color
    /// 포인트 색 (하트, 진화 이펙트)
    let accent: Color
    /// 화면 바탕
    let background: Color
    /// 카드 바탕
    let surface: Color
    /// 카드 안에서 한 단계 더 들어간 바탕
    let surfaceAlt: Color
    let textPrimary: Color
    let textSecondary: Color
    /// 테두리·구분선
    let outline: Color
}

// MARK: - 테마

nonisolated enum AppTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case peach
    case mint
    case lavender
    case butter
    case sky
    case cocoa

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .peach: "복숭아"
        case .mint: "민트"
        case .lavender: "라벤더"
        case .butter: "버터"
        case .sky: "하늘"
        case .cocoa: "코코아"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .peach:
            ThemePalette(
                primary: Color(light: 0xFF8FA3, dark: 0xFF9FB1),
                primarySoft: Color(light: 0xFFE4EA, dark: 0x4A2F38),
                accent: Color(light: 0xFF5D8F, dark: 0xFF7FA6),
                background: Color(light: 0xFFF6F8, dark: 0x1C1518),
                surface: Color(light: 0xFFFFFF, dark: 0x2A2126),
                surfaceAlt: Color(light: 0xFFF0F4, dark: 0x352A30),
                textPrimary: Color(light: 0x4A3B44, dark: 0xF4ECEF),
                textSecondary: Color(light: 0x9A8A92, dark: 0xB6A6AE),
                outline: Color(light: 0xFFDCE4, dark: 0x3F323A)
            )
        case .mint:
            ThemePalette(
                primary: Color(light: 0x49C5B6, dark: 0x5FD6C7),
                primarySoft: Color(light: 0xD8F4F0, dark: 0x1F3F3B),
                accent: Color(light: 0x2FA8A0, dark: 0x6FE0D2),
                background: Color(light: 0xF2FBF9, dark: 0x121A19),
                surface: Color(light: 0xFFFFFF, dark: 0x1E2827),
                surfaceAlt: Color(light: 0xEBF8F5, dark: 0x273231),
                textPrimary: Color(light: 0x334946, dark: 0xE9F4F2),
                textSecondary: Color(light: 0x85A19D, dark: 0xA3BAB6),
                outline: Color(light: 0xD3EEE9, dark: 0x2F3B3A)
            )
        case .lavender:
            ThemePalette(
                primary: Color(light: 0xA78BFA, dark: 0xB69DFB),
                primarySoft: Color(light: 0xEBE3FF, dark: 0x332A4D),
                accent: Color(light: 0x8B5CF6, dark: 0xC0AAFF),
                background: Color(light: 0xF8F5FF, dark: 0x171425),
                surface: Color(light: 0xFFFFFF, dark: 0x241F36),
                surfaceAlt: Color(light: 0xF2EDFF, dark: 0x2D2742),
                textPrimary: Color(light: 0x433A5C, dark: 0xEFEAFB),
                textSecondary: Color(light: 0x8F86A8, dark: 0xADA3C6),
                outline: Color(light: 0xE5DCFA, dark: 0x362F4D)
            )
        case .butter:
            ThemePalette(
                primary: Color(light: 0xF0A93B, dark: 0xF5BA59),
                primarySoft: Color(light: 0xFCEBCC, dark: 0x453419),
                accent: Color(light: 0xE08A15, dark: 0xFFC978),
                background: Color(light: 0xFFFBF2, dark: 0x1B1712),
                surface: Color(light: 0xFFFFFF, dark: 0x282219),
                surfaceAlt: Color(light: 0xFFF5E4, dark: 0x332C21),
                textPrimary: Color(light: 0x4F4130, dark: 0xF6EFE3),
                textSecondary: Color(light: 0x9C8C74, dark: 0xBCAE96),
                outline: Color(light: 0xF6E6C8, dark: 0x3C3427)
            )
        case .sky:
            ThemePalette(
                primary: Color(light: 0x5BA9E8, dark: 0x74BAF2),
                primarySoft: Color(light: 0xDCEDFB, dark: 0x1E3448),
                accent: Color(light: 0x3489CE, dark: 0x8FCBFF),
                background: Color(light: 0xF3F9FF, dark: 0x111921),
                surface: Color(light: 0xFFFFFF, dark: 0x1C262F),
                surfaceAlt: Color(light: 0xEBF4FD, dark: 0x25313B),
                textPrimary: Color(light: 0x36444F, dark: 0xE9F1F8),
                textSecondary: Color(light: 0x869AAA, dark: 0xA4B6C4),
                outline: Color(light: 0xD7E8F6, dark: 0x2C3945)
            )
        case .cocoa:
            ThemePalette(
                primary: Color(light: 0xB08663, dark: 0xC69C79),
                primarySoft: Color(light: 0xF0E2D4, dark: 0x40311F),
                accent: Color(light: 0x8E6543, dark: 0xD9B08C),
                background: Color(light: 0xFCF7F2, dark: 0x191512),
                surface: Color(light: 0xFFFFFF, dark: 0x262019),
                surfaceAlt: Color(light: 0xF7EFE6, dark: 0x312921),
                textPrimary: Color(light: 0x4B3D31, dark: 0xF3EBE2),
                textSecondary: Color(light: 0x9B8878, dark: 0xBBA997),
                outline: Color(light: 0xEADCCC, dark: 0x3A3127)
            )
        }
    }
}

// MARK: - Environment

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = AppTheme.peach.palette
}

extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Color 헬퍼

extension Color {
    /// 라이트/다크 모드에 따라 자동으로 갈라지는 색.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(rgb: dark)
                : UIColor(rgb: light)
        })
    }
}

extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
