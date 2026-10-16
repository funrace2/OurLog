//
//  NaverKeys.swift
//  OurLog
//
//  네이버 키는 OurLog/NaverKeys.plist 에서 읽는다 (.gitignore 에 들어 있어 저장소에 올라가지 않는다).
//  값이 비어 있으면 지도는 MapKit, 검색은 Apple 지도 검색으로 대신한다.
//
//    MapKeyId            네이버 클라우드 플랫폼 Maps 의 Client ID   (지도 표시)
//    SearchClientId      네이버 개발자센터 검색 API 의 Client ID     (장소 검색)
//    SearchClientSecret  네이버 개발자센터 검색 API 의 Client Secret
//
//  ⚠️ 키가 앱 안에 그대로 들어간다. 둘이서만 쓰는 앱이라 감수하기로 한 선택이고,
//     공개 배포할 때는 검색을 서버(프록시) 경유로 바꿔야 한다.
//

import Foundation

nonisolated enum NaverKeys {
    private static let values: [String: String] = {
        guard let url = Bundle.main.url(forResource: "NaverKeys", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: String]
        else { return [:] }
        return dict
    }()

    private static func value(_ key: String) -> String? {
        guard let v = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
        return v
    }

    static var mapKeyId: String? { value("MapKeyId") }
    static var searchClientId: String? { value("SearchClientId") }
    static var searchClientSecret: String? { value("SearchClientSecret") }

    static var hasMapKey: Bool { mapKeyId != nil }
    static var hasSearchKey: Bool { searchClientId != nil && searchClientSecret != nil }
}
