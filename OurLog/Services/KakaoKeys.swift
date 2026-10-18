//
//  KakaoKeys.swift
//  OurLog
//
//  카카오 REST API 키는 OurLog/KakaoKeys.plist 에서 읽는다 (.gitignore 에 들어 있다).
//  있으면 장소 검색을 카카오 로컬 키워드 검색으로 한다 (위치 기준·거리순·최대 45개).
//
//  ⚠️ 키가 앱 안에 그대로 들어간다. 둘이서만 쓰는 앱이라 감수한 선택이다.
//

import Foundation

nonisolated enum KakaoKeys {
    static let restApiKey: String? = {
        guard let url = Bundle.main.url(forResource: "KakaoKeys", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: String],
              let key = dict["RestApiKey"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty
        else { return nil }
        return key
    }()

    static var hasKey: Bool { restApiKey != nil }
}
