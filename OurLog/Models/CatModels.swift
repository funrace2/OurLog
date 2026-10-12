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
    var requiredAffection: Int {
        switch self {
        case .egg: 0
        case .crackedEgg: 60
        case .kitten: 180
        case .teen: 400
        case .adult: 800
        case .radiant: 1500
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

    /// 애정도를 더하고, 단계가 올랐으면 새 단계를 돌려준다.
    mutating func gain(_ action: AffectionAction) -> CatStage? {
        let before = stage
        affection += action.points
        let after = stage
        return after > before ? after : nil
    }
}
