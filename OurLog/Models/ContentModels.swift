//
//  ContentModels.swift
//  OurLog
//
//  장소 · 캘린더 일정 · 데이트 일기 모델. 전부 커플 단위로 공유된다.
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - 장소

nonisolated struct PlaceCategory: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var symbol: String
    var colorHex: UInt32
    /// 기본 카테고리를 "삭제"한 표시. 기본 카테고리는 저장소에 없고 앱이 붙여 주는 거라,
    /// 지운 걸 기억하려면 숨김 표시를 저장해야 한다. (직접 만든 카테고리는 그냥 지운다)
    var isHidden: Bool? = nil
    /// 만든 순서대로 보여주기 위해
    var createdAt: Date? = nil

    var color: Color { Color(hex: colorHex) }

    var isDefault: Bool { Self.defaults.contains { $0.id == id } }

    static let restaurant = PlaceCategory(id: "cat-food", name: "맛집", symbol: "fork.knife", colorHex: 0xF08A6E)
    static let cafe = PlaceCategory(id: "cat-cafe", name: "카페", symbol: "cup.and.saucer.fill", colorHex: 0xB08663)
    static let date = PlaceCategory(id: "cat-date", name: "데이트", symbol: "heart.fill", colorHex: 0xFF8FA3)
    static let travel = PlaceCategory(id: "cat-travel", name: "여행", symbol: "airplane", colorHex: 0x5BA9E8)
    static let wishlist = PlaceCategory(id: "cat-wish", name: "가보고 싶은 곳", symbol: "star.fill", colorHex: 0xF0C04E)

    static let defaults: [PlaceCategory] = [.restaurant, .cafe, .date, .travel, .wishlist]
}

nonisolated struct SavedPlace: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var categoryID: String
    var memo: String
    /// 실제로 가봤는지
    var isVisited: Bool
    var createdBy: String
    var createdAt: Date
    /// 가게 홈페이지·인스타그램 등 (네이버 검색 결과에 있을 때만). 예전에 저장한 장소는 nil.
    var link: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        categoryID: String,
        memo: String = "",
        isVisited: Bool = false,
        createdBy: String,
        createdAt: Date = .now,
        link: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.categoryID = categoryID
        self.memo = memo
        self.isVisited = isVisited
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.link = link
    }
}

/// 검색 결과 한 건. 아직 저장 전 상태라 id 가 없다.
nonisolated struct PlaceSearchResult: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let address: String
    let category: String
    let latitude: Double
    let longitude: Double
    var link: String? = nil

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 캘린더

nonisolated struct CalendarEvent: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var memo: String
    /// 누가 만든 일정인지. 색으로 구분해서 보여준다.
    var createdBy: String
    /// 연결된 장소 (있으면 일정에서 지도로 바로 넘어간다)
    var placeID: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        isAllDay: Bool = true,
        memo: String = "",
        createdBy: String,
        placeID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate ?? startDate
        self.isAllDay = isAllDay
        self.memo = memo
        self.createdBy = createdBy
        self.placeID = placeID
    }

    /// 이 일정이 해당 날짜에 걸쳐 있는지
    func occurs(on day: Date) -> Bool {
        let cal = Calendar.dday
        let target = cal.startOfDay(for: day)
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: endDate)
        return target >= start && target <= end
    }
}

// MARK: - 데이트 일기

nonisolated struct DiaryEntry: Identifiable, Codable, Hashable, Sendable {
    enum Mood: String, Codable, CaseIterable, Sendable, Identifiable {
        case happy, love, calm, excited, tired, sad

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .happy: "😊"
            case .love: "🥰"
            case .calm: "☺️"
            case .excited: "🤩"
            case .tired: "😴"
            case .sad: "🥲"
            }
        }

        var label: String {
            switch self {
            case .happy: "즐거움"
            case .love: "사랑스러움"
            case .calm: "편안함"
            case .excited: "신남"
            case .tired: "피곤함"
            case .sad: "아쉬움"
            }
        }
    }

    let id: String
    var title: String
    var body: String
    var date: Date
    var mood: Mood
    /// 저장된 사진 식별자. 지금은 로컬 파일명, Firebase 연동 후에는 Storage 경로가 들어간다.
    var photoIDs: [String]
    var placeID: String?
    var authorID: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        body: String = "",
        date: Date = .now,
        mood: Mood = .happy,
        photoIDs: [String] = [],
        placeID: String? = nil,
        authorID: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.date = date
        self.mood = mood
        self.photoIDs = photoIDs
        self.placeID = placeID
        self.authorID = authorID
        self.createdAt = createdAt
    }
}
