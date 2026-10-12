//
//  LocalCoupleRepository.swift
//  OurLog
//
//  Firebase 연동 전까지 쓰는 로컬 저장소.
//  Application Support 밑 JSON 한 덩어리로 저장해서 앱을 껐다 켜도 데이터가 남는다.
//
//  ⚠️ 이 구현은 기기 안에서만 동작하므로 실제 "두 사람 간 공유"는 되지 않는다.
//     화면과 데이터 흐름을 먼저 완성하기 위한 임시 구현이고,
//     FirestoreCoupleRepository 로 교체하면 그대로 공유가 된다.
//

import Foundation

@MainActor
final class LocalCoupleRepository: CoupleRepository {

    // MARK: 디스크 표현

    private struct Database: Codable {
        var snapshots: [String: CoupleSnapshot] = [:]
        /// userID -> coupleID
        var membership: [String: String] = [:]
        /// inviteCode -> coupleID
        var invites: [String: String] = [:]
    }

    private var db = Database()
    private var continuations: [String: [UUID: AsyncStream<CoupleSnapshot>.Continuation]] = [:]

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(filename: String = "ourlog-local.json") {
        let base = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appending(path: filename)
        load()
    }

    // MARK: 영속화

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode(Database.self, from: data)
        else { return }
        db = decoded
    }

    private func persist() {
        guard let data = try? encoder.encode(db) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 저장 후 구독자에게 알린다.
    private func commit(_ coupleID: String) {
        persist()
        guard let snapshot = db.snapshots[coupleID] else { return }
        continuations[coupleID]?.values.forEach { $0.yield(snapshot) }
    }

    // MARK: CoupleRepository

    func loadSnapshot(coupleID: String) async throws -> CoupleSnapshot {
        guard let snapshot = db.snapshots[coupleID] else { throw RepositoryError.coupleNotFound }
        return snapshot
    }

    func snapshotStream(coupleID: String) -> AsyncStream<CoupleSnapshot> {
        AsyncStream { continuation in
            let token = UUID()
            continuations[coupleID, default: [:]][token] = continuation

            if let snapshot = db.snapshots[coupleID] {
                continuation.yield(snapshot)
            }

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.continuations[coupleID]?.removeValue(forKey: token)
                }
            }
        }
    }

    func saveCouple(_ couple: Couple) async throws {
        guard db.snapshots[couple.id] != nil else { throw RepositoryError.coupleNotFound }
        db.snapshots[couple.id]?.couple = couple
        for member in couple.members {
            db.membership[member.id] = couple.id
        }
        commit(couple.id)
    }

    func upsert<T: CoupleDocument>(_ item: T, coupleID: String) async throws {
        guard db.snapshots[coupleID] != nil else { throw RepositoryError.coupleNotFound }
        mutateCollection(T.self, in: coupleID) { list in
            if let index = list.firstIndex(where: { $0.id == item.id }) {
                list[index] = item
            } else {
                list.append(item)
            }
        }
        commit(coupleID)
    }

    func delete<T: CoupleDocument>(_ type: T.Type, id: String, coupleID: String) async throws {
        guard db.snapshots[coupleID] != nil else { throw RepositoryError.coupleNotFound }
        mutateCollection(type, in: coupleID) { list in
            list.removeAll { $0.id == id }
        }
        commit(coupleID)
    }

    func createCouple(owner: Partner, startDate: Date) async throws -> Couple {
        var code = InviteCode.generate()
        while db.invites[code] != nil { code = InviteCode.generate() }

        let couple = Couple(
            id: UUID().uuidString,
            inviteCode: code,
            members: [owner],
            startDate: startDate,
            theme: .peach,
            cat: CatState()
        )

        db.snapshots[couple.id] = CoupleSnapshot(couple: couple)
        db.membership[owner.id] = couple.id
        db.invites[code] = couple.id
        commit(couple.id)
        return couple
    }

    func joinCouple(inviteCode: String, partner: Partner) async throws -> Couple {
        let code = InviteCode.normalize(inviteCode)
        guard let coupleID = db.invites[code], var snapshot = db.snapshots[coupleID] else {
            throw RepositoryError.invalidInviteCode
        }
        // 이미 들어와 있으면 그대로 돌려준다 (재로그인)
        if snapshot.couple.members.contains(where: { $0.id == partner.id }) {
            return snapshot.couple
        }
        guard snapshot.couple.members.count < 2 else { throw RepositoryError.coupleAlreadyFull }

        snapshot.couple.members.append(partner)
        db.snapshots[coupleID] = snapshot
        db.membership[partner.id] = coupleID
        commit(coupleID)
        return snapshot.couple
    }

    func coupleID(forUser userID: String) async throws -> String? {
        db.membership[userID]
    }

    // MARK: 컬렉션 접근

    /// 문서 타입에 맞는 배열을 찾아 수정한다.
    /// Firestore 로 옮기면 이 분기 자체가 `collection(T.collection)` 한 줄로 사라진다.
    private func mutateCollection<T: CoupleDocument>(
        _ type: T.Type,
        in coupleID: String,
        _ body: (inout [T]) -> Void
    ) {
        guard var snapshot = db.snapshots[coupleID] else { return }

        switch type {
        case is Anniversary.Type:
            apply(&snapshot.anniversaries, body)
        case is SavedPlace.Type:
            apply(&snapshot.places, body)
        case is PlaceCategory.Type:
            apply(&snapshot.categories, body)
        case is CalendarEvent.Type:
            apply(&snapshot.events, body)
        case is DiaryEntry.Type:
            apply(&snapshot.diaries, body)
        default:
            assertionFailure("등록되지 않은 컬렉션: \(T.collection)")
        }

        db.snapshots[coupleID] = snapshot
    }

    /// 구체 타입 배열을 제네릭 클로저에 연결해 주는 다리.
    private func apply<Stored, T: CoupleDocument>(
        _ storage: inout [Stored],
        _ body: (inout [T]) -> Void
    ) {
        guard var typed = storage as? [T] else { return }
        body(&typed)
        guard let back = typed as? [Stored] else { return }
        storage = back
    }
}
