//
//  FirebaseSetup.swift
//  OurLog
//
//  GoogleService-Info.plist 가 번들에 있을 때만 Firebase 를 켠다.
//  파일이 없으면 앱은 예전처럼 기기 안에서만 동작하는 로컬 모드로 돈다.
//

import Foundation
import FirebaseCore

enum FirebaseSetup {
    private(set) static var isConfigured = false

    static func configureIfAvailable() {
        guard !isConfigured,
              Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        else { return }
        FirebaseApp.configure()
        isConfigured = true
    }
}
