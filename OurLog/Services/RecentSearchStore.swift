//
//  RecentSearchStore.swift
//  OurLog
//
//  지도에서 검색한 검색어와 열어 본 장소 기록. 내 폰에만 남는다 (상대방과 공유하지 않는다).
//

import Foundation

nonisolated struct RecentSearch: Identifiable, Codable, Hashable, Sendable {
    enum Kind: Codable, Hashable, Sendable {
        case query(String)
        case place(PlaceSearchResult)
    }

    var id = UUID()
    let kind: Kind
    var date: Date

    var title: String {
        switch kind {
        case .query(let text): text
        case .place(let result): result.name
        }
    }

    /// 같은 기록인지 (같은 검색어 / 같은 장소면 새로 쌓지 않고 맨 위로 올린다)
    var key: String {
        switch kind {
        case .query(let text): "q|\(text)"
        case .place(let result): "p|\(result.name)|\(result.address)"
        }
    }
}

@Observable
final class RecentSearchStore {
    static let shared = RecentSearchStore()

    private static let defaultsKey = "map.recentSearches"
    private static let limit = 50

    private(set) var items: [RecentSearch] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([RecentSearch].self, from: data) {
            items = decoded
        }
    }

    func addQuery(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        add(RecentSearch(kind: .query(trimmed), date: .now))
    }

    func addPlace(_ result: PlaceSearchResult) {
        add(RecentSearch(kind: .place(result), date: .now))
    }

    func remove(ids: Set<RecentSearch.ID>) {
        items.removeAll { ids.contains($0.id) }
        save()
    }

    private func add(_ item: RecentSearch) {
        items.removeAll { $0.key == item.key }
        items.insert(item, at: 0)
        if items.count > Self.limit { items.removeLast(items.count - Self.limit) }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
