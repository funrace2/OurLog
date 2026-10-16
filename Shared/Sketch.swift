//
//  Sketch.swift
//  OurLog
//
//  손으로 그린 듯 살짝 떨리는 도형들 (SpendLog 에서 가져옴).
//  떨림은 고정 시드로 만들어서 같은 상자는 다시 그려도 늘 같은 모양이다.
//

import SwiftUI

// MARK: - 고정 난수

nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - 떨리는 사각형 (닫힌 도형이라 채우기 + 테두리 가능)

nonisolated struct SketchRectangle: Shape {
    var seed: UInt64
    var roughness: CGFloat = 1.8

    func path(in rect: CGRect) -> Path {
        var g = SeededGenerator(seed: seed)
        let r = rect.insetBy(dx: 3, dy: 3)
        let corners = [
            CGPoint(x: r.minX, y: r.minY),
            CGPoint(x: r.maxX, y: r.minY),
            CGPoint(x: r.maxX, y: r.maxY),
            CGPoint(x: r.minX, y: r.maxY),
        ]
        var pts: [CGPoint] = []
        for i in 0..<4 {
            let a = corners[i]
            let b = corners[(i + 1) % 4]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(1, hypot(dx, dy))
            let nx = -dy / len, ny = dx / len
            let segments = max(3, Int(len / 26))
            for s in 0..<segments {
                let t = CGFloat(s) / CGFloat(segments)
                let amp = s == 0 ? roughness * 0.5 : roughness
                let off = CGFloat.random(in: -amp...amp, using: &g)
                pts.append(CGPoint(x: a.x + dx * t + nx * off, y: a.y + dy * t + ny * off))
            }
        }
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        p.closeSubpath()
        return p
    }
}

// MARK: - 떨리는 선 (구분선)

nonisolated struct SketchLine: Shape {
    enum Axis { case horizontal, vertical }
    var seed: UInt64
    var axis: Axis = .horizontal
    var roughness: CGFloat = 1.4

    func path(in rect: CGRect) -> Path {
        var g = SeededGenerator(seed: seed)
        let a: CGPoint, b: CGPoint
        switch axis {
        case .horizontal:
            a = CGPoint(x: rect.minX + 2, y: rect.midY)
            b = CGPoint(x: rect.maxX - 2, y: rect.midY)
        case .vertical:
            a = CGPoint(x: rect.midX, y: rect.minY + 2)
            b = CGPoint(x: rect.midX, y: rect.maxY - 2)
        }
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(1, hypot(dx, dy))
        let nx = -dy / len, ny = dx / len
        let seg = max(4, Int(len / 22))
        var p = Path()
        p.move(to: a)
        for s in 1...seg {
            let t = CGFloat(s) / CGFloat(seg)
            let off = s == seg ? 0 : CGFloat.random(in: -roughness...roughness, using: &g)
            p.addLine(to: CGPoint(x: a.x + dx * t + nx * off, y: a.y + dy * t + ny * off))
        }
        return p
    }
}

// MARK: - 떨리는 원 (오늘 표시, 동그라미)

nonisolated struct SketchCircle: Shape {
    var seed: UInt64
    var roughness: CGFloat = 1.6

    func path(in rect: CGRect) -> Path {
        var g = SeededGenerator(seed: seed)
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2 - 2, ry = rect.height / 2 - 2
        let steps = 22
        var p = Path()
        for s in 0...steps {
            let ang = CGFloat(s) / CGFloat(steps) * .pi * 2
            let jitter = CGFloat.random(in: -roughness...roughness, using: &g)
            let pt = CGPoint(x: c.x + cos(ang) * (rx + jitter), y: c.y + sin(ang) * (ry + jitter))
            if s == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

// MARK: - 손그림 상자

extension View {
    /// 종이를 깔고 잉크로 떨리는 테두리를 두른다.
    func sketchBox(
        seed: UInt64,
        fill: Color,
        stroke: Color = Theme.ink,
        roughness: CGFloat = 1.8,
        lineWidth: CGFloat = 2.2
    ) -> some View {
        let shape = SketchRectangle(seed: seed, roughness: roughness)
        return self
            .background(shape.fill(fill))
            .overlay(shape.stroke(stroke, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)))
    }
}
