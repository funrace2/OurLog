//
//  ResultsPanel.swift
//  OurLog
//
//  지도 아래에서 올라오는 검색 결과 판. 위로 끌면 펼쳐지고, 아래로 내리면 제목만 남는다.
//

import SwiftUI

enum ResultsPanelLevel: CaseIterable {
    /// 제목 줄만 (지도를 넓게 볼 때)
    case collapsed
    /// 결과 몇 개가 보이는 기본 높이
    case middle
    /// 검색창 아래까지 펼친 높이
    case expanded
}

struct ResultsPanelHeights {
    /// 판이 들어갈 수 있는 세로 공간 (상단바 아래 ~ 탭바 위)
    let available: CGFloat

    func height(for level: ResultsPanelLevel) -> CGFloat {
        switch level {
        case .collapsed: 78
        case .middle: min(320, available * 0.45)
        case .expanded: max(320, available - 130)   // 검색창 + 카테고리 칩은 가리지 않는다
        }
    }

    /// 지도에서 가려지는 높이. 펼쳤을 땐 지도가 거의 안 보이니 기본 높이까지만 잡는다
    /// (그래야 내 위치 버튼·지도 가운데가 화면 위로 튀어 오르지 않는다).
    func inset(for level: ResultsPanelLevel) -> CGFloat {
        min(height(for: level), height(for: .middle))
    }
}

struct ResultsPanel<Header: View, Content: View>: View {
    @Binding var level: ResultsPanelLevel
    let heights: ResultsPanelHeights
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    @Environment(\.palette) private var palette
    @GestureState private var dragOffset: CGFloat = 0

    private var currentHeight: CGFloat {
        let base = heights.height(for: level)
        return min(max(base - dragOffset, heights.height(for: .collapsed)), heights.height(for: .expanded))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 손잡이 + 제목. 여기를 끌어서 높이를 바꾸고, 누르면 접었다 폈다 한다.
            VStack(spacing: 8) {
                SketchLine(seed: 52)
                    .stroke(palette.inkSoft, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 6)
                header
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .contentShape(.rect)
            .gesture(drag)
            .onTapGesture {
                withAnimation(.snappy) { level = level == .collapsed ? .middle : .collapsed }
            }

            SketchDivider(seed: 57).padding(.horizontal, 12)

            ScrollView {
                content
            }
            .scrollDisabled(level == .collapsed)
        }
        .frame(height: currentHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .clipped()
        .sketchBox(seed: 333, fill: palette.surface, roughness: 1.3, lineWidth: 1.6)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                // 손을 뗀 위치보다 조금 더 나아갈 자리를 보고, 가장 가까운 높이로 붙인다
                let target = heights.height(for: level) - value.predictedEndTranslation.height
                let nearest = ResultsPanelLevel.allCases.min {
                    abs(heights.height(for: $0) - target) < abs(heights.height(for: $1) - target)
                } ?? level
                withAnimation(.snappy) { level = nearest }
            }
    }
}
