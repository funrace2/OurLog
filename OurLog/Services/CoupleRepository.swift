//
//  CoupleRepository.swift
//  OurLog
//
//  데이터 저장소 추상화.
//
//  지금은 LocalCoupleRepository(기기 안 JSON) 를 쓰고,
//  Firebase 프로젝트가 준비되면 FirestoreCoupleRepository 를 같은 프로토콜로 만들어
//  AppEnvironment 에서 갈아끼우기만 하면 된다. 화면 코드는 건드릴 일이 없다.
//

import Foundation

// MARK: - 문서

/// 커플 문서 하위 컬렉션에 들어가는 항목.
/// Firestore 로 옮기면 `couples/{coupleID}/{collection}/{id}` 경로가 된다.
nonisolated protocol CoupleDocument: Identifiable, Codable, Sendable where ID == String {
    static var collection: String { get }
}

nonisolated extension Anniversary: CoupleDocument {
    static var collection: String { "anniversaries" }
}

nonisolated extension SavedPlace: CoupleDocument {
    static var collection: String { "places" }
}

nonisolated extension PlaceCategory: CoupleDocument {
    static var collection: String { "categories" }
}

nonisolated extension CalendarEvent: CoupleDocument {
    static var collection: String { "events" }
}

nonisolated extension DiaryEntry: CoupleDocument {
    static var collection: String { "diaries" }
}

// MARK: - 스냅샷

/// 커플 하나가 가진 모든 공유 데이터.
nonisolated struct CoupleSnapshot: Codable, Sendable {
    var couple: Couple
    var anniversaries: [Anniversary] = []
    var places: [SavedPlace] = []
    var categories: [PlaceCategory] = PlaceCategory.defaults
    var events: [CalendarEvent] = []
    var diaries: [DiaryEntry] = []
}

extension CoupleSnapshot {
    /// 같은 id 가 있으면 바꾸고, 없으면 추가한다.
    mutating func upsert<T: CoupleDocument>(_ item: T) {
        mutate(T.self) { list in
            if let index = list.firstIndex(where: { $0.id == item.id }) {
                list[index] = item
            } else {
                list.append(item)
            }
        }
    }

    mutating func remove<T: CoupleDocument>(_ type: T.Type, id: String) {
        mutate(type) { list in list.removeAll { $0.id == id } }
    }

    /// 문서 타입에 맞는 배열을 통째로 바꾼다 (Firestore 리스너가 컬렉션 단위로 받아올 때).
    mutating func replace<T: CoupleDocument>(_ items: [T]) {
        mutate(T.self) { list in list = items }
    }

    /// 문서 타입에 맞는 배열을 찾아 수정한다.
    private mutating func mutate<T: CoupleDocument>(_ type: T.Type, _ body: (inout [T]) -> Void) {
        switch type {
        case is Anniversary.Type: Self.apply(&anniversaries, body)
        case is SavedPlace.Type: Self.apply(&places, body)
        case is PlaceCategory.Type: Self.apply(&categories, body)
        case is CalendarEvent.Type: Self.apply(&events, body)
        case is DiaryEntry.Type: Self.apply(&diaries, body)
        default: assertionFailure("등록되지 않은 컬렉션: \(T.collection)")
        }
    }

    /// 구체 타입 배열을 제네릭 클로저에 연결해 주는 다리.
    private static func apply<Stored, T: CoupleDocument>(_ storage: inout [Stored], _ body: (inout [T]) -> Void) {
        guard var typed = storage as? [T] else { return }
        body(&typed)
        guard let back = typed as? [Stored] else { return }
        storage = back
    }
}

// MARK: - 저장소

nonisolated enum RepositoryError: LocalizedError {
    case coupleNotFound
    case invalidInviteCode
    case coupleAlreadyFull

    var errorDescription: String? {
        switch self {
        case .coupleNotFound: "커플 정보를 찾을 수 없어요."
        case .invalidInviteCode: "초대코드가 맞지 않아요. 다시 확인해 주세요."
        case .coupleAlreadyFull: "이미 두 사람이 연결된 커플이에요."
        }
    }
}

/// 프로젝트 설정이 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 라 앱 전체가 메인 액터 위에서 돈다.
/// 저장소도 같은 자리에 두어 화면 코드에서 격리 전환 없이 쓰게 한다.
@MainActor
protocol CoupleRepository {
    /// 커플 전체 데이터를 한 번 읽는다.
    func loadSnapshot(coupleID: String) async throws -> CoupleSnapshot

    /// 다른 기기(상대방)에서 바뀐 내용을 이어서 받는다.
    /// 로컬 구현은 자기 변경만 흘려보내고, Firestore 구현은 실시간 리스너를 연결한다.
    func snapshotStream(coupleID: String) -> AsyncStream<CoupleSnapshot>

    func saveCouple(_ couple: Couple) async throws

    func upsert<T: CoupleDocument>(_ item: T, coupleID: String) async throws
    func delete<T: CoupleDocument>(_ type: T.Type, id: String, coupleID: String) async throws

    // 커플 만들기 / 연결하기
    func createCouple(owner: Partner, startDate: Date) async throws -> Couple
    func joinCouple(inviteCode: String, partner: Partner) async throws -> Couple
    /// 이 사용자가 이미 속한 커플 id
    func coupleID(forUser userID: String) async throws -> String?
}

// MARK: - 초대코드

nonisolated enum InviteCode {
    /// 헷갈리는 글자(0/O, 1/I)를 뺀 6자리 코드
    static func generate() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    static func normalize(_ raw: String) -> String {
        raw.uppercased().filter { $0.isLetter || $0.isNumber }
    }
}
