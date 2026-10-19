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

/// 사진·후기를 찾을 장소. 저장 전(검색 결과)이든 저장 후든 이름과 주소만 있으면 된다.
nonisolated struct PlaceLookup: Sendable {
    let name: String
    let address: String
    /// 같은 가게면 저장 전후로 캐시를 같이 쓴다
    var key: String { "\(name)|\(address)" }
}

extension SavedPlace {
    nonisolated var lookup: PlaceLookup { PlaceLookup(name: name, address: address) }
}

extension PlaceSearchResult {
    nonisolated var lookup: PlaceLookup { PlaceLookup(name: name, address: address) }
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

    /// 이미 받아 둔 게 있으면 바로 돌려준다 (화면을 열자마자 빈 칸 없이 보여주려고)
    func cachedInfo(for place: PlaceLookup) -> PlaceInfo? {
        cache[place.key]
    }

    func info(for place: PlaceLookup) async -> PlaceInfo {
        if let cached = cache[place.key] { return cached }
        guard Self.isAvailable else { return PlaceInfo() }

        let strategies = Self.strategies(for: place)
        async let photos = fetchPhotos(strategies)
        async let posts = fetchPosts(strategies)
        let info = PlaceInfo(photos: await photos, posts: await posts)
        // 둘 다 실패(네트워크 등)했으면 캐시하지 않아 다음에 다시 시도한다
        if !info.photos.isEmpty || !info.posts.isEmpty {
            cache[place.key] = info
        }
        return info
    }

    // MARK: 검색어

    /// 한 번의 검색: 검색어 + 결과를 거를 가게 이름
    private struct Strategy: Equatable {
        let query: String
        let name: String
    }

    /// 1) 이름 전체 + 지역 (원래 방식 — 네이버로 저장한 장소는 대부분 이걸로 잘 찾는다)
    /// 2) 핵심 단어 + 지역 (카카오가 "브루크 성수"처럼 지역을 붙인 이름일 때 보충)
    /// 앞에서 다 채우면 뒤는 부르지 않는다. 이름이 한 단어면 둘이 같아서 한 번만 검색한다.
    private static func strategies(for place: PlaceLookup) -> [Strategy] {
        let area = area(of: place)
        let full = Strategy(query: join(place.name, area), name: fullName(place.name))
        let core = Strategy(query: join(coreName(place.name), area), name: coreName(place.name))
        return full == core ? [full] : [full, core]
    }

    /// 네이버 지도에서 열 때 쓰는 검색어 (이름 전체 + 지역)
    static func query(for place: PlaceLookup) -> String {
        join(place.name, area(of: place))
    }

    /// 도로명 주소에는 동 이름이 없어서 동이 없으면 구·군 단위로 붙인다.
    private static func area(of place: PlaceLookup) -> String? {
        // 건물 동 번호("101동")가 지역으로 잡히지 않게 숫자로 시작하는 건 뺀다
        let tokens = place.address.split(separator: " ").map(String.init).filter { !($0.first?.isNumber ?? true) }
        return tokens.first { $0.hasSuffix("동") || ($0.hasSuffix("가") && $0.contains("동")) }
            ?? tokens.first { $0.hasSuffix("구") || $0.hasSuffix("군") }
            ?? tokens.dropFirst().first
    }

    private static func join(_ name: String, _ area: String?) -> String {
        [name, area].compactMap { $0 }.joined(separator: " ")
    }

    /// 원래 방식의 거르는 이름: 지점명("성수점")만 떼고 붙여 쓴다. "한입베이글 성수점" → "한입베이글"
    private static func fullName(_ name: String) -> String {
        var words = name.split(separator: " ").map(String.init)
        if words.count > 1, let last = words.last, last.hasSuffix("점") { words.removeLast() }
        return words.joined()
    }

    /// 가게 이름의 핵심 단어. 지점("~점")을 빼고 가장 긴 단어.
    ///   "브루크 성수" → "브루크", "카페 어니언 성수" → "어니언", "피넛버터바나나" → 그대로
    private static func coreName(_ name: String) -> String {
        let words = name.split(separator: " ").map(String.init)
        guard words.count > 1 else { return name }
        let candidates = words.filter { !($0.hasSuffix("점") && $0.count > 1) }
        return (candidates.isEmpty ? words : candidates).max { $0.count < $1.count } ?? name
    }

    private static func mentions(_ text: String, _ name: String) -> Bool {
        stripTags(text).replacingOccurrences(of: " ", with: "").localizedCaseInsensitiveContains(name)
    }

    // MARK: 이미지

    private struct ImageResponse: Decodable {
        struct Item: Decodable { let title: String; let link: String }
        let items: [Item]
    }

    private func fetchPhotos(_ strategies: [Strategy]) async -> [PlacePhoto] {
        let limit = 6
        var photos: [PlacePhoto] = []
        for strategy in strategies where photos.count < limit {
            // 사진은 제목에 가게 이름이 안 붙은 경우가 많아서 후보를 넉넉히(30개) 받아 거른다
            guard let response: ImageResponse = try? await request(
                "image", query: strategy.query, display: 30, extra: ["filter": "large"]
            ) else { continue }

            let found = response.items
                .filter { Self.mentions($0.title, strategy.name) }
                .compactMap { URL(string: $0.link) }
                .filter { $0.scheme == "https" }       // http 사진은 iOS 가 막는다
                .map(PlacePhoto.init)
            for photo in found where !photos.contains(photo) && photos.count < limit {
                photos.append(photo)
            }
        }
        return photos
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

    private func fetchPosts(_ strategies: [Strategy]) async -> [BlogPost] {
        let limit = 4
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyyMMdd"

        var posts: [BlogPost] = []
        for strategy in strategies where posts.count < limit {
            guard let response: BlogResponse = try? await request("blog", query: strategy.query) else { continue }

            let found = response.items
                .filter { Self.mentions($0.title + $0.description, strategy.name) }
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
            for post in found where !posts.contains(where: { $0.url == post.url }) && posts.count < limit {
                posts.append(post)
            }
        }
        return posts
    }

    // MARK: 공통

    private func request<T: Decodable>(_ api: String, query: String, display: Int = 10, extra: [String: String] = [:]) async throws -> T {
        guard let clientID = NaverKeys.searchClientId, let secret = NaverKeys.searchClientSecret else {
            throw URLError(.userAuthenticationRequired)
        }
        var components = URLComponents(string: "https://naverapihub.apigw.ntruss.com/search/v1/\(api)")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "display", value: String(display)),   // 넉넉히 받아서 가게 이름으로 거른다
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
