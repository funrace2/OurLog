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

    /// 일기 사진을 어디에 공유할지.
    /// false: Firestore 문서에 줄인 사진을 직접 넣는다 (무료 요금제로 동작, 긴 변 1000px)
    /// true : Firebase Storage 에 원본에 가깝게 올린다 (Blaze 요금제 필요)
    static let useFirebaseStorage = false

    /// NaverKeys.plist 에 키가 있으면 네이버 지도·검색을, 없으면 MapKit 을 쓴다.
    static var useNaverMaps: Bool { NaverKeys.hasMapKey }

    static var usesFirebase: Bool { FirebaseSetup.isConfigured }

    static func makeAuthService() -> AuthService {
        if useAppleSignIn { return AppleAuthService() }
        return usesFirebase ? GoogleAuthService() : LocalAuthService()
    }

    static func makeRepository() -> CoupleRepository {
        usesFirebase ? FirestoreCoupleRepository() : LocalCoupleRepository()
    }

    static func makePhotoRemote(coupleID: String) -> PhotoRemote? {
        guard usesFirebase else { return nil }
        return useFirebaseStorage ? FirebasePhotoRemote(coupleID: coupleID) : FirestorePhotoRemote(coupleID: coupleID)
    }

    static func makePlaceSearchService() -> PlaceSearchService {
        NaverKeys.hasSearchKey ? NaverPlaceSearchService() : MapKitPlaceSearchService()
    }

    static func makeAppState() -> AppState {
        AppState(auth: makeAuthService(), repository: makeRepository())
    }
}
