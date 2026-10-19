//
//  KeyboardDismiss.swift
//  OurLog
//
//  입력칸 바깥을 탭하면 키보드를 닫는다. 앱 창(UIWindow) 하나에 걸어서 시트까지 전부 적용된다.
//
//  - 탭을 가로채지 않는다 (버튼은 그대로 눌리고 키보드만 같이 닫힌다)
//  - 다른 입력칸을 누른 거면 닫지 않는다 (커서만 그쪽으로 옮겨 간다)
//

import SwiftUI
import UIKit

/// RootView 배경에 한 번 깔아 두면, 이 뷰가 창에 붙는 순간 창에 탭 인식기를 단다.
struct KeyboardDismissOnTap: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window else { return }
            // 같은 창에 두 번 달지 않는다
            if window.gestureRecognizers?.contains(where: { $0 is DismissKeyboardTap }) == true { return }
            window.addGestureRecognizer(DismissKeyboardTap(window: window))
        }
    }
}

private final class DismissKeyboardTap: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    private weak var targetWindow: UIWindow?

    init(window: UIWindow) {
        targetWindow = window
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(handleTap))
        cancelsTouchesInView = false   // 버튼·목록 탭은 그대로 전달
        delegate = self
    }

    @objc private func handleTap() {
        targetWindow?.endEditing(true)
    }

    // 다른 제스처(스크롤, 지도 등)와 동시에 인식해도 된다
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    // 입력칸(과 그 안의 지우기 버튼 등)을 누른 거면 키보드를 닫지 않는다
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView || current is UISearchBar { return false }
            view = current.superview
        }
        return true
    }
}
