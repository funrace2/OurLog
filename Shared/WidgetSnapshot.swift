//
//  WidgetSnapshot.swift
//  OurLog
//
//  앱 → 위젯으로 넘기는 작은 데이터. App Group 공용 UserDefaults 에 JSON 으로 넣어 둔다.
//  위젯은 Firebase 에 직접 붙지 않고 이것만 읽는다 (앱을 열 때마다 앱이 새로 써 준다).
//
//  디데이·기념일 남은 날은 "날짜"로 저장하고 위젯이 그날그날 계산하므로,
//  앱을 며칠 안 열어도 숫자는 매일 맞게 바뀐다.
//

import Foundation

nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct Member: Codable, Equatable, Sendable {
        var name: String
        var emoji: String
    }

    struct Upcoming: Codable, Equatable, Sendable {
        var title: String
        var emoji: String
        var date: Date
    }

    var startDate: Date
    var me: Member
    var partner: Member?
    var catName: String
    var catStage: CatStage
    /// AccessorySlot.rawValue → 아이템 id
    var accessoryIDs: [String: String]
    /// 다가오는 기념일 몇 개 (날짜 순). 지난 건 위젯이 건너뛴다.
    var upcoming: [Upcoming]
    var theme: AppTheme

    // MARK: 저장 위치

    /// Xcode 의 Signing & Capabilities > App Groups 에 앱·위젯 둘 다 이 이름으로 켜 둬야 한다.
    static let appGroup = "group.gaeuni.OurLog"
    private static let key = "widgetSnapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// 바뀐 게 있을 때만 쓰고 true 를 돌려준다.
    @discardableResult
    func save() -> Bool {
        guard let defaults = Self.defaults, let data = try? JSONEncoder().encode(self) else { return false }
        if defaults.data(forKey: Self.key) == data { return false }
        defaults.set(data, forKey: Self.key)
        return true
    }

    static func clear() {
        defaults?.removeObject(forKey: key)
    }

    // MARK: 날짜 계산 (앱의 디데이 규칙과 같다: 만난 날이 1일)

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }

    func daysTogether(on day: Date = .now) -> Int {
        let cal = Self.calendar
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: startDate), to: cal.startOfDay(for: day)).day ?? 0
        return days + 1
    }

    /// 그날 기준으로 아직 안 지난 첫 기념일과 남은 날
    func nextUpcoming(on day: Date = .now) -> (item: Upcoming, daysLeft: Int)? {
        let cal = Self.calendar
        let today = cal.startOfDay(for: day)
        for item in upcoming {
            let left = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: item.date)).day ?? -1
            if left >= 0 { return (item, left) }
        }
        return nil
    }

    var accessories: [AccessorySlot: String] {
        accessoryIDs.reduce(into: [:]) { result, pair in
            if let slot = AccessorySlot(rawValue: pair.key) { result[slot] = pair.value }
        }
    }
}
