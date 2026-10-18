//
//  PlaceInfoService.swift
//  OurLog
//
//  장소 상세 화면에 붙일 사진과 블로그 후기.
//  네이버 이미지 검색 · 블로그 검색 (NAVER API HUB) 으로 "가게 이름 + 지역" 을 찾아,
//  제목·내용에 가게 이름이 들어간 결과만 남긴다.
//
//  공식 장소 사진이 아니라 웹·블로그 사진이라 가끔 다른 곳이 섞일 수 있다.
//  (네이버 지도의 공식 사진·영업시간·리뷰를 가져오는 공개 API 는 없다)
//

import Foundation

nonisolated struct PlacePhoto: Identifiable, Hashable, Sendable {
    let url: URL
    var id: URL { url }
}

nonisolated struct BlogPost: Identifiable, Hashable, Sendable {
    let title: String
    let summary: String
    let blogger: String
    let date: Date?
    let url: URL
    var id: URL { url }
}

nonisolated struct PlaceInfo: Sendable {
    var photos: [PlacePhoto] = []
    var posts: [BlogPost] = []
}

@MainActor
final class PlaceInfoService {
    static let shared = PlaceInfoService()

    /// 한 번 연 장소는 앱을 끌 때까지 다시 묻지 않는다
    private var cache: [String: PlaceInfo] = [:]

    static var isAvailable: Bool { NaverKeys.hasSearchKey }

    func info(for place: SavedPlace) async -> PlaceInfo {
        if let cached = cache[place.id] { return cached }
        guard Self.isAvailable else { return PlaceInfo() }

        let query = Self.query(for: place)
        let name = Self.coreName(place.name)

        async let photos = fetchPhotos(query: query, name: name)
        async let posts = fetchPosts(query: query, name: name)
        let info = PlaceInfo(photos: await photos, posts: await posts)
        // 둘 다 실패(네트워크 등)했으면 캐시하지 않아 다음에 다시 시도한다
        if !info.photos.isEmpty || !info.posts.isEmpty {
            cache[place.id] = info
        }
        return info
    }

    // MARK: 검색어

    /// "브루크" + "성동구" — 도로명 주소에는 동 이름이 없어서 구·군 단위로 붙인다.
    static func query(for place: SavedPlace) -> String {
        // 건물 동 번호("101동")가 지역으로 잡히지 않게 숫자로 시작하는 건 뺀다
        let tokens = place.address.split(separator: " ").map(String.init).filter { !($0.first?.isNumber ?? true) }
        let area = tokens.first { $0.hasSuffix("동") || ($0.hasSuffix("가") && $0.contains("동")) }
            ?? tokens.first { $0.hasSuffix("구") || $0.hasSuffix("군") }
            ?? tokens.dropFirst().first
        return [place.name, area].compactMap { $0 }.joined(separator: " ")
    }

    /// 결과를 거를 때 쓰는 가게 이름. 지점명("성수점")과 공백을 뗀다.
    static func coreName(_ name: String) -> String {
        var parts = name.split(separator: " ").map(String.init)
        if parts.count > 1, let last = parts.last, last.hasSuffix("점") { parts.removeLast() }
        return parts.joined()
    }

    private static func mentions(_ text: String, _ name: String) -> Bool {
        stripTags(text).replacingOccurrences(of: " ", with: "").localizedCaseInsensitiveContains(name)
    }

    // MARK: 이미지

    private struct ImageResponse: Decodable {
        struct Item: Decodable { let title: String; let link: String }
        let items: [Item]
    }

    private func fetchPhotos(query: String, name: String) async -> [PlacePhoto] {
        guard let response: ImageResponse = try? await request("image", query: query, extra: ["filter": "large"]) else {
            return []
        }
        return response.items
            .filter { Self.mentions($0.title, name) }
            .compactMap { URL(string: $0.link) }
            .filter { $0.scheme == "https" }       // http 사진은 iOS 가 막는다
            .prefix(6)
            .map(PlacePhoto.init)
    }

    // MARK: 블로그

    private struct BlogResponse: Decodable {
        struct Item: Decodable {
            let title: String
            let link: String
            let description: String
            let bloggername: String
            let postdate: String
        }
        let items: [Item]
    }

    private func fetchPosts(query: String, name: String) async -> [BlogPost] {
        guard let response: BlogResponse = try? await request("blog", query: query) else { return [] }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyyMMdd"

        return response.items
            .filter { Self.mentions($0.title + $0.description, name) }
            .compactMap { item -> BlogPost? in
                guard let url = URL(string: item.link) else { return nil }
                return BlogPost(
                    title: Self.stripTags(item.title),
                    summary: Self.stripTags(item.description),
                    blogger: item.bloggername,
                    date: dateFormatter.date(from: item.postdate),
                    url: url
                )
            }
            .prefix(4)
            .map { $0 }
    }

    // MARK: 공통

    private func request<T: Decodable>(_ api: String, query: String, extra: [String: String] = [:]) async throws -> T {
        guard let clientID = NaverKeys.searchClientId, let secret = NaverKeys.searchClientSecret else {
            throw URLError(.userAuthenticationRequired)
        }
        var components = URLComponents(string: "https://naverapihub.apigw.ntruss.com/search/v1/\(api)")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "display", value: "10"),   // 넉넉히 받아서 가게 이름으로 거른다
            URLQueryItem(name: "sort", value: "sim"),
            URLQueryItem(name: "format", value: "json"),
        ] + extra.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: components.url!)
        request.setValue(clientID, forHTTPHeaderField: "X-NCP-APIGW-API-KEY-ID")
        request.setValue(secret, forHTTPHeaderField: "X-NCP-APIGW-API-KEY")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            print("네이버 \(api) 검색 오류 \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
