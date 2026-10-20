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

    /// 떨림 점 사이 간격. 변 길이로 나누지 않고 고정 간격으로 찍어서,
    /// 상자 크기가 바뀌어도 (키보드에 맞춰 줄어들 때 등) 남은 부분의 모양은 그대로 두고 변만 짧아지게 한다.
    private static let step: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: 3, dy: 3)
        let tl = CGPoint(x: r.minX, y: r.minY)
        let tr = CGPoint(x: r.maxX, y: r.minY)
        let br = CGPoint(x: r.maxX, y: r.maxY)
        let bl = CGPoint(x: r.minX, y: r.maxY)

        // 모서리마다 따로 조금 흔든다
        var cg = SeededGenerator(seed: seed)
        let half = roughness * 0.5
        let corners = [tl, tr, br, bl].map {
            CGPoint(x: $0.x + .random(in: -half...half, using: &cg),
                    y: $0.y + .random(in: -half...half, using: &cg))
        }

        // 변 안쪽 점들. 늘 왼쪽 위 기준 모서리에서부터 찍는다 (아래·오른쪽 끝이 움직여도 앞쪽 점은 안 바뀐다).
        func interior(from a: CGPoint, to b: CGPoint, edge: UInt64) -> [CGPoint] {
            var g = SeededGenerator(seed: seed &+ (edge &+ 1) &* 0x9E37_79B9_7F4A_7C15)
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(1, hypot(dx, dy))
            let ux = dx / len, uy = dy / len
            var pts: [CGPoint] = []
            var d = Self.step
            while d < len - Self.step * 0.4 {
                let off = CGFloat.random(in: -roughness...roughness, using: &g)
                pts.append(CGPoint(x: a.x + ux * d - uy * off, y: a.y + uy * d + ux * off))
                d += Self.step
            }
            return pts
        }

        var p = Path()
        p.move(to: corners[0])
        for pt in interior(from: tl, to: tr, edge: 0) { p.addLine(to: pt) }
        p.addLine(to: corners[1])
        for pt in interior(from: tr, to: br, edge: 1) { p.addLine(to: pt) }
        p.addLine(to: corners[2])
        for pt in interior(from: bl, to: br, edge: 2).reversed() { p.addLine(to: pt) }
        p.addLine(to: corners[3])
        for pt in interior(from: tl, to: bl, edge: 3).reversed() { p.addLine(to: pt) }
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

    /// 사진·지도처럼 꽉 찬 내용을 손그림 테두리 모양대로 잘라 두른다
    /// (sketchBox 는 테두리가 안쪽으로 들어와 그려져서, 꽉 찬 내용이면 모서리가 테두리 밖으로 삐져나온다).
    func sketchFramed(
        seed: UInt64,
        stroke: Color = Theme.ink,
        roughness: CGFloat = 1.8,
        lineWidth: CGFloat = 2.2
    ) -> some View {
        let shape = SketchRectangle(seed: seed, roughness: roughness)
        return self
            .clipShape(shape)
            .overlay(shape.stroke(stroke, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)))
    }
}
