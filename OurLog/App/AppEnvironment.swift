//
//  AppEnvironment.swift
//  OurLog
//
//  어떤 구현을 쓸지 한 군데에서 정한다.
//  Firebase / Apple 로그인 / 네이버 지도가 준비되면 여기 스위치만 바꾸면 된다.
//

import Foundation

@MainActor
enum AppEnvironment {

    /// Signing & Capabilities 에 "Sign in with Apple" 을 추가한 뒤 true 로 바꾼다.
    static let useAppleSignIn = false

    /// 네이버 지도/검색 키가 준비되면 true 로 바꾼다. (자세한 절차는 SETUP.md)
    static let useNaverMaps = false

    static func makeAuthService() -> AuthService {
        useAppleSignIn ? AppleAuthService() : LocalAuthService()
    }

    static func makeRepository() -> CoupleRepository {
        // Firebase 연동 후: return FirestoreCoupleRepository()
        LocalCoupleRepository()
    }

    static func makePlaceSearchService() -> PlaceSearchService {
        useNaverMaps ? NaverPlaceSearchService() : MapKitPlaceSearchService()
    }

    static func makeAppState() -> AppState {
        AppState(auth: makeAuthService(), repository: makeRepository())
    }
}
