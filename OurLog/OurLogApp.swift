//
//  OurLogApp.swift
//  OurLog
//
//  Created by 구현모 on 9/21/26.
//

import SwiftUI
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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Google 로그인 후 앱으로 돌아오는 주소 처리
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }
}
