//
//  PixelSprite.swift
//  OurLog
//
//  문자 격자로 적은 도트 그림을 그대로 화면에 찍는다.
//  번지지 않게 칸마다 사각형을 채우므로 어떤 크기로 키워도 도트가 또렷하다.
//

import SwiftUI

nonisolated struct PixelSprite: Sendable {
    let rows: [String]
    let width: Int
    let height: Int
    /// 투명이 아닌 칸만 미리 풀어 둔다 (그릴 때마다 문자열을 다시 훑지 않도록)
    let cells: [Cell]

    struct Cell: Sendable {
        let x: Int
        let y: Int
        let key: Character
    }

    init(rows: [String]) {
        self.rows = rows
        self.height = rows.count
        self.width = rows.map(\.count).max() ?? 0
        var cells: [Cell] = []
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." {
                cells.append(Cell(x: x, y: y, key: ch))
            }
        }
        self.cells = cells
    }
}

// MARK: - 합성

extension PixelSprite {
    /// 빈 캔버스.
    static func blank(width: Int, height: Int) -> [[Character]] {
        Array(repeating: Array(repeating: ".", count: width), count: height)
    }

    /// 다른 스프라이트를 (x, y) 에 겹쳐 찍는다. 투명 칸은 건너뛴다.
    static func stamp(_ sprite: PixelSprite, at x: Int, _ y: Int, into grid: inout [[Character]]) {
        for cell in sprite.cells {
            let gx = x + cell.x, gy = y + cell.y
            guard gy >= 0, gy < grid.count, gx >= 0, gx < grid[gy].count else { continue }
            grid[gy][gx] = cell.key
        }
    }

    init(grid: [[Character]]) {
        self.init(rows: grid.map { String($0) })
    }
}

// MARK: - 색

extension Color {
    nonisolated init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - 그리기

/// 스프라이트 하나를 canvasCells x canvasCells 칸 화면의 아래 가운데에 놓고 그린다.
struct PixelSpriteView: View {
    let sprite: PixelSprite
    /// 몇 칸짜리 화면 기준으로 그릴지. 여러 스프라이트를 같은 칸 크기로 맞출 때 쓴다.
    var canvasCells: Int?
    var palette: [Character: Color] = PixelPalette.colors

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let cellsAcross = CGFloat(canvasCells ?? max(sprite.width, sprite.height))
            let unit = min(size.width, size.height) / cellsAcross
            // 아래 가운데 정렬
            let originX = (size.width - CGFloat(sprite.width) * unit) / 2
            let originY = size.height - CGFloat(sprite.height) * unit

            for cell in sprite.cells {
                guard let color = palette[cell.key] else { continue }
                // 칸 사이에 머리카락 같은 틈이 보이지 않도록 아주 살짝 겹쳐 그린다
                let rect = CGRect(
                    x: originX + CGFloat(cell.x) * unit,
                    y: originY + CGFloat(cell.y) * unit,
                    width: unit + 0.5,
                    height: unit + 0.5
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
    }
}
