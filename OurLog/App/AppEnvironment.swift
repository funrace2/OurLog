//
//  AppEnvironment.swift
//  OurLog
//
//  어떤 구현을 쓸지 한 군데에서 정한다.
//
//  GoogleService-Info.plist 가 번들에 있으면 자동으로 Firebase(Google 로그인 + Firestore)로,
//  없으면 기기 안에서만 도는 로컬 모드로 동작한다.
//

import Foundation

@MainActor
enum AppEnvironment {

    /// 유료 개발자 계정으로 "Sign in with Apple" capability 를 켠 뒤 true 로 바꾼다.
    static let useAppleSignIn = false

    /// 일기 사진을 Firebase Storage 로 공유할지.
    /// 새 Firebase 프로젝트는 Storage 에 Blaze 요금제가 필요해서, 요금제를 올린 뒤 true 로 바꾼다.
    /// false 면 사진은 찍은 사람 기기에만 남는다 (일기 글은 그래도 공유된다).
    static let useFirebaseStorage = false

    /// 네이버 지도/검색 키가 준비되면 true 로 바꾼다. (자세한 절차는 SETUP.md)
    static let useNaverMaps = false

    static var usesFirebase: Bool { FirebaseSetup.isConfigured }

    static func makeAuthService() -> AuthService {
        if useAppleSignIn { return AppleAuthService() }
        return usesFirebase ? GoogleAuthService() : LocalAuthService()
    }

    static func makeRepository() -> CoupleRepository {
        usesFirebase ? FirestoreCoupleRepository() : LocalCoupleRepository()
    }

    static func makePhotoRemote(coupleID: String) -> PhotoRemote? {
        guard usesFirebase, useFirebaseStorage else { return nil }
        return FirebasePhotoRemote(coupleID: coupleID)
    }

    static func makePlaceSearchService() -> PlaceSearchService {
        useNaverMaps ? NaverPlaceSearchService() : MapKitPlaceSearchService()
    }

    static func makeAppState() -> AppState {
        AppState(auth: makeAuthService(), repository: makeRepository())
    }
}
