//
//  OurLogApp.swift
//  OurLog
//
//  Created by 구현모 on 9/21/26.
//

import SwiftUI
import UIKit
import GoogleSignIn
import NMapsMap

@main
struct OurLogApp: App {
    init() {
        // GoogleService-Info.plist 가 있으면 Firebase 를 켠다 (없으면 로컬 모드)
        FirebaseSetup.configureIfAvailable()

        // 네이버 지도 키 (NaverKeys.plist). 없으면 지도 화면이 MapKit 으로 대신 그린다.
        if let key = NaverKeys.mapKeyId {
            NMFAuthManager.shared().client = NMFNcpKeyClient(ncpKeyId: key, beta: false)
        }

        // 하단 탭 글씨를 손글씨로. (상단바 제목·버튼은 화면마다 paperTitle / ToolbarTextButton 으로 직접 그린다.
        // 예전의 UINavigationBar 전역 글꼴 설정은 상단바 색을 SwiftUI 로 칠하면 무시돼서 뺐다.)
        if let tabFont = UIFont(name: Theme.fontName, size: 13) {
            let item = UITabBarItemAppearance()
            item.normal.titleTextAttributes = [.font: tabFont]
            item.selected.titleTextAttributes = [.font: tabFont]
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.stackedLayoutAppearance = item
            appearance.inlineLayoutAppearance = item
            appearance.compactInlineLayoutAppearance = item
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
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
