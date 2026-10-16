//
//  OurLogApp.swift
//  OurLog
//
//  Created by 구현모 on 9/21/26.
//

import SwiftUI
import UIKit
import GoogleSignIn

@main
struct OurLogApp: App {
    init() {
        // GoogleService-Info.plist 가 있으면 Firebase 를 켠다 (없으면 로컬 모드)
        FirebaseSetup.configureIfAvailable()

        // 내비게이션 제목과 탭 글씨도 손글씨로 (배경색은 화면마다 테마 종이색으로 칠한다)
        if let title = UIFont(name: Theme.fontName, size: 24),
           let large = UIFont(name: Theme.fontName, size: 38),
           let tab = UIFont(name: Theme.fontName, size: 13) {
            let ink = UIColor(Theme.ink)
            UINavigationBar.appearance().titleTextAttributes = [.font: title, .foregroundColor: ink]
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: large, .foregroundColor: ink]
            UITabBarItem.appearance().setTitleTextAttributes([.font: tab], for: .normal)
            UIBarButtonItem.appearance().setTitleTextAttributes([.font: UIFont(name: Theme.fontName, size: 19) ?? title], for: .normal)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Google 로그인 후 앱으로 돌아오는 주소 처리
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }
}
