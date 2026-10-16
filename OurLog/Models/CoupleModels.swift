//
//  CoupleModels.swift
//  OurLog
//
//  커플·사용자·기념일 도메인 모델.
//

import Foundation
import SwiftUI

// MARK: - 사용자

nonisolated struct Partner: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var displayName: String
    /// 프로필로 쓰는 이모지. 사진 업로드 전까지의 기본 아바타.
    var emoji: String
    /// 생일 (기념일 목록에 자동으로 올라간다)
    var birthday: Date?

    init(id: String, displayName: String, emoji: String = "🐣", birthday: Date? = nil) {
        self.id = id
        self.displayName = displayName
        self.emoji = emoji
        self.birthday = birthday
    }
}

// MARK: - 커플

nonisolated struct Couple: Identifiable, Codable, Hashable, Sendable {
    let id: String
    /// 상대가 입력해서 연결하는 6자리 코드
    var inviteCode: String
    var members: [Partner]
    /// 사귀기 시작한 날 (디데이 기준)
    var startDate: Date
    var theme: AppTheme
    var cat: CatState

    /// 아직 한 명만 들어와 있는 상태
    var isWaitingForPartner: Bool { members.count < 2 }

    func partner(otherThan userID: String) -> Partner? {
        members.first { $0.id != userID }
    }

    func member(id: String) -> Partner? {
        members.first { $0.id == id }
    }
}

// MARK: - 디데이 계산

extension Couple {
    /// 사귄 지 며칠째인지. 만난 날을 1일로 센다 (한국식).
    var daysTogether: Int {
        Calendar.dday.daysBetween(startDate, and: .now) + 1
    }
}

nonisolated extension Calendar {
    /// 디데이 계산 전용 캘린더. 시간대에 따라 하루가 밀리지 않도록 현재 시간대를 고정해 쓴다.
    static let dday: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()

    /// 두 날짜 사이의 "날짜 수" 차이. 시·분은 무시한다.
    func daysBetween(_ from: Date, and to: Date) -> Int {
        let a = startOfDay(for: from)
        let b = startOfDay(for: to)
        return dateComponents([.day], from: a, to: b).day ?? 0
    }
}

// MARK: - 기념일

nonisolated struct Anniversary: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// 사귄 날 기준으로 자동 생성되는 100일·1주년 등
        case milestone
        /// 생일
        case birthday
        /// 직접 추가한 기념일
        case custom
    }

    let id: String
    var title: String
    /// 기념일 당일 (연도 포함)
    var date: Date
    var kind: Kind
    /// 매년 반복되는지 (생일·1주년 등)
    var repeatsYearly: Bool
    /// 며칠 전에 알림을 받을지. 비어 있으면 알림 없음.
    var notifyDaysBefore: [Int]
    var emoji: String

    init(
        id: String = UUID().uuidString,
        title: String,
        date: Date,
        kind: Kind = .custom,
        repeatsYearly: Bool = false,
        notifyDaysBefore: [Int] = [0, 1],
        emoji: String = "🎀"
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.kind = kind
        self.repeatsYearly = repeatsYearly
        self.notifyDaysBefore = notifyDaysBefore
        self.emoji = emoji
    }

    /// 오늘 기준으로 다음에 돌아오는 날짜. 반복되지 않으면 date 그대로.
    var nextOccurrence: Date {
        guard repeatsYearly else { return date }
        let cal = Calendar.dday
        let today = cal.startOfDay(for: .now)
        var comps = cal.dateComponents([.month, .day], from: date)
        comps.year = cal.component(.year, from: today)
        guard let thisYear = cal.date(from: comps) else { return date }
        if thisYear >= today { return thisYear }
        comps.year = cal.component(.year, from: today) + 1
        return cal.date(from: comps) ?? thisYear
    }

    /// 다음 기념일까지 남은 날. 오늘이면 0.
    var daysRemaining: Int {
        Calendar.dday.daysBetween(.now, and: nextOccurrence)
    }

    var isToday: Bool { daysRemaining == 0 }
}

// MARK: - 기념일 자동 생성

nonisolated enum MilestoneGenerator {
    /// 100일 단위 + 주년을 만들어 준다.
    /// - Parameters:
    ///   - startDate: 사귀기 시작한 날
    ///   - upcomingCount: 오늘 이후로 몇 개를 만들지
    static func milestones(from startDate: Date, upcomingCount: Int = 6) -> [Anniversary] {
        let cal = Calendar.dday
        let today = cal.startOfDay(for: .now)
        let start = cal.startOfDay(for: startDate)

        var result: [Anniversary] = []

        // 100일, 200일, ... (만난 날을 1일로 세므로 n일째는 start + (n-1)일)
        var dayCount = 100
        while result.count < upcomingCount * 2, dayCount <= 10_000 {
            if let date = cal.date(byAdding: .day, value: dayCount - 1, to: start), date >= today {
                result.append(
                    Anniversary(
                        id: "milestone-day-\(dayCount)",
                        title: "\(dayCount)일",
                        date: date,
                        kind: .milestone,
                        repeatsYearly: false,
                        emoji: "💗"
                    )
                )
            }
            dayCount += 100
        }

        // 1주년, 2주년, ...
        for year in 1...20 {
            guard let date = cal.date(byAdding: .year, value: year, to: start), date >= today else { continue }
            result.append(
                Anniversary(
                    id: "milestone-year-\(year)",
                    title: "\(year)주년",
                    date: date,
                    kind: .milestone,
                    repeatsYearly: false,
                    emoji: "🎉"
                )
            )
        }

        return result
            .sorted { $0.nextOccurrence < $1.nextOccurrence }
            .prefix(upcomingCount)
            .map { $0 }
    }
}
