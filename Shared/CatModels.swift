//
//  CatModels.swift
//  OurLog
//
//  둘이 같이 키우는 고양이 캐릭터. 앱을 쓸수록 애정도가 쌓이고 6단계까지 진화한다.
//

import Foundation
import SwiftUI

// MARK: - 진화 단계

nonisolated enum CatStage: Int, CaseIterable, Codable, Identifiable, Sendable, Comparable {
    case egg = 1        // 알
    case crackedEgg     // 반알
    case kitten         // 애기고양이
    case teen           // 청소년고양이
    case adult          // 어른고양이
    case radiant        // 최종 진화

    var id: Int { rawValue }

    static func < (lhs: CatStage, rhs: CatStage) -> Bool { lhs.rawValue < rhs.rawValue }

    var displayName: String {
        switch self {
        case .egg: "알"
        case .crackedEgg: "반알"
        case .kitten: "애기 고양이"
        case .teen: "청소년 고양이"
        case .adult: "어른 고양이"
        case .radiant: "반짝 고양이"
        }
    }

    /// 이 단계가 되기 위해 필요한 누적 애정도
    /// 둘이 평소처럼 쓰면(하루 25점 안팎) 대략: 반알 1주, 애기 1달, 청소년 3달, 어른 6달, 반짝 1년
    var requiredAffection: Int {
        switch self {
        case .egg: 0
        case .crackedEgg: 150
        case .kitten: 700
        case .teen: 2_200
        case .adult: 4_500
        case .radiant: 9_000
        }
    }

    var next: CatStage? { CatStage(rawValue: rawValue + 1) }

    /// 단계마다 바뀌는 한 줄 소개
    var tagline: String {
        switch self {
        case .egg: "무언가 안에서 꼬물거려요"
        case .crackedEgg: "껍질에 금이 갔어요!"
        case .kitten: "이제 막 세상에 나왔어요"
        case .teen: "호기심이 아주 많아요"
        case .adult: "듬직해졌어요"
        case .radiant: "세상에서 제일 예쁜 고양이"
        }
    }

    static func stage(forAffection affection: Int) -> CatStage {
        allCases.last { affection >= $0.requiredAffection } ?? .egg
    }
}

// MARK: - 애정도를 주는 행동

nonisolated enum AffectionAction: String, Codable, Sendable {
    case dailyCheckIn
    case addDiary
    case addPhoto
    case savePlace
    case visitPlace
    case addEvent
    case celebrateAnniversary
    case pet

    var points: Int {
        switch self {
        case .dailyCheckIn: 5
        case .addDiary: 20
        case .addPhoto: 5
        case .savePlace: 10
        case .visitPlace: 15
        case .addEvent: 5
        case .celebrateAnniversary: 30
        case .pet: 2
        }
    }

    /// 하루에 애정도를 받을 수 있는 횟수 (둘이 합쳐서). 넘으면 기록은 되지만 애정도는 오르지 않는다.
    var dailyLimit: Int {
        switch self {
        case .dailyCheckIn, .pet, .celebrateAnniversary: 1
        case .addDiary, .visitPlace: 2
        case .savePlace, .addEvent, .addPhoto: 3
        }
    }

    var label: String {
        switch self {
        case .dailyCheckIn: "오늘도 방문"
        case .addDiary: "데이트 일기 작성"
        case .addPhoto: "사진 추가"
        case .savePlace: "장소 저장"
        case .visitPlace: "장소 방문 체크"
        case .addEvent: "일정 추가"
        case .celebrateAnniversary: "기념일 챙기기"
        case .pet: "쓰다듬기"
        }
    }
}

// MARK: - 꾸미기 아이템

/// 고양이가 착용하는 아이템. 슬롯마다 하나씩만 낄 수 있다.
nonisolated enum AccessorySlot: String, Codable, CaseIterable, Sendable {
    case head, neck, face

    var label: String {
        switch self {
        case .head: "머리"
        case .neck: "목"
        case .face: "얼굴"
        }
    }
}

nonisolated struct CatAccessory: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let slot: AccessorySlot
}

/// 방을 꾸미는 아이템. 슬롯(벽/바닥/창가 등)마다 하나씩.
nonisolated enum RoomSlot: String, Codable, CaseIterable, Sendable {
    case wall, floor, window, side

    var label: String {
        switch self {
        case .wall: "벽"
        case .floor: "바닥"
        case .window: "창가"
        case .side: "옆자리"
        }
    }
}

nonisolated struct RoomItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let slot: RoomSlot
}

// 아이템 목록(DecorCatalog)과 도트 그림은 자동 생성 파일 Features/Cat/SpriteData.swift 에 있다.

// MARK: - 고양이 상태

// 슬롯을 딕셔너리 키로 쓰면서도 JSON 이 {"head": "acc-ribbon"} 형태로 나오도록 한다.
// (기본 Codable 은 String 이 아닌 키를 [키, 값, 키, 값...] 배열로 인코딩해서 Firestore 에 넣기 곤란하다.)
extension AccessorySlot: CodingKeyRepresentable {}
extension RoomSlot: CodingKeyRepresentable {}

nonisolated struct CatState: Codable, Hashable, Sendable {
    var name: String
    var affection: Int
    /// 슬롯별로 착용 중인 액세서리 id
    var equippedAccessories: [AccessorySlot: String]
    /// 슬롯별로 배치한 방 아이템 id
    var placedRoomItems: [RoomSlot: String]
    /// 마지막으로 출석 애정도를 받은 날
    var lastCheckIn: Date?
    /// 성장 기준 버전. 기준을 바꿀 때 예전 애정도를 한 번만 옮기기 위해. (없으면 1)
    var balanceVersion: Int?
    /// 하루 상한을 세는 날짜("2026-10-20")와 그날 행동별 횟수 (둘이 공유)
    var todayKey: String?
    var todayCounts: [String: Int]?

    static let currentBalance = 2

    init(
        name: String = "아직 이름이 없어요",
        affection: Int = 0,
        equippedAccessories: [AccessorySlot: String] = [:],
        placedRoomItems: [RoomSlot: String] = [:],
        lastCheckIn: Date? = nil
    ) {
        self.name = name
        self.affection = affection
        self.equippedAccessories = equippedAccessories
        self.placedRoomItems = placedRoomItems
        self.lastCheckIn = lastCheckIn
        self.balanceVersion = Self.currentBalance
    }

    var stage: CatStage { .stage(forAffection: affection) }

    /// 다음 단계까지의 진행도 (0...1). 최종 단계면 1.
    var progressToNextStage: Double {
        guard let next = stage.next else { return 1 }
        let floorValue = stage.requiredAffection
        let ceilingValue = next.requiredAffection
        guard ceilingValue > floorValue else { return 1 }
        return Double(affection - floorValue) / Double(ceilingValue - floorValue)
    }

    /// 다음 단계까지 남은 애정도. 최종 단계면 nil.
    var affectionToNextStage: Int? {
        guard let next = stage.next else { return nil }
        return max(0, next.requiredAffection - affection)
    }

    enum GainResult: Equatable {
        /// 애정도가 올랐다. 단계가 올랐으면 새 단계.
        case gained(evolvedTo: CatStage?)
        /// 오늘 이 행동으로 받을 수 있는 만큼 다 받았다
        case capped
    }

    /// 애정도를 더한다. 하루 상한을 넘었으면 더하지 않는다.
    mutating func gain(_ action: AffectionAction, now: Date = .now) -> GainResult {
        let day = Self.dayKey(now)
        var counts = todayKey == day ? (todayCounts ?? [:]) : [:]
        let used = counts[action.rawValue] ?? 0
        guard used < action.dailyLimit else { return .capped }
        counts[action.rawValue] = used + 1
        todayKey = day
        todayCounts = counts

        let before = stage
        affection += action.points
        let after = stage
        return .gained(evolvedTo: after > before ? after : nil)
    }

    /// 애정도 없이 "오늘 했음"만 남긴다 (예전 기록과 맞출 때)
    mutating func markUsedToday(_ action: AffectionAction, now: Date = .now) {
        let day = Self.dayKey(now)
        var counts = todayKey == day ? (todayCounts ?? [:]) : [:]
        counts[action.rawValue] = max(counts[action.rawValue] ?? 0, 1)
        todayKey = day
        todayCounts = counts
    }

    /// 오늘 이 행동으로 애정도를 받은 횟수
    func usedToday(_ action: AffectionAction, now: Date = .now) -> Int {
        guard todayKey == Self.dayKey(now) else { return 0 }
        return todayCounts?[action.rawValue] ?? 0
    }

    private static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: 성장 기준 변경

    /// 예전 기준(1)의 단계별 애정도
    private static let balanceV1 = [0, 60, 180, 400, 800, 1_500]

    /// 예전 기준으로 쌓인 애정도를 새 기준으로 옮긴다. 단계와 단계 안 진행률이 그대로 유지된다.
    /// 이미 옮겼으면 아무것도 하지 않고 false.
    mutating func rebalanceIfNeeded() -> Bool {
        guard (balanceVersion ?? 1) < Self.currentBalance else { return false }
        let old = Self.balanceV1
        let new = CatStage.allCases.map(\.requiredAffection)

        if affection >= old.last! {
            // 예전 최종 단계를 넘은 만큼은 마지막 구간 비율로
            affection = new.last! + (affection - old.last!) * (new.last! - new[new.count - 2]) / (old.last! - old[old.count - 2])
        } else if let i = (0..<(old.count - 1)).first(where: { affection < old[$0 + 1] }) {
            let progress = Double(affection - old[i]) / Double(old[i + 1] - old[i])
            affection = new[i] + Int((Double(new[i + 1] - new[i]) * progress).rounded())
        }
        balanceVersion = Self.currentBalance
        return true
    }
}
