//
//  SafariView.swift
//  OurLog
//
//  앱을 벗어나지 않고 웹페이지(블로그 후기, 네이버 지도 장소 페이지)를 연다.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(Theme.ink)
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// .sheet(item:) 로 띄울 웹페이지
struct WebPage: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
