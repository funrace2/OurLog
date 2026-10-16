//
//  FirestoreCoupleRepository.swift
//  OurLog
//
//  Firestore 저장소. 두 사람이 같은 커플 문서를 실시간으로 함께 본다.
//
//  couples/{coupleID}                  Couple + memberIDs (보안 규칙용)
//  couples/{coupleID}/{collection}/{id} 기념일 · 장소 · 카테고리 · 일정 · 일기
//  users/{uid}      → { coupleID }      로그인 후 내 커플 찾기
//  invites/{code}   → { coupleID }      초대코드로 합류
//
//  규칙은 저장소 루트의 firestore.rules 참고.
//

import Foundation
import FirebaseFirestore

@MainActor
final class FirestoreCoupleRepository: CoupleRepository {
    private let db = Firestore.firestore()

    private func coupleRef(_ id: String) -> DocumentReference {
        db.collection("couples").document(id)
    }

    private func userRef(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    private func inviteRef(_ code: String) -> DocumentReference {
        db.collection("invites").document(code)
    }

    /// 커플 문서에 들어갈 값. 규칙에서 쓰려고 memberIDs 를 따로 펼쳐 둔다.
    private func coupleData(_ couple: Couple) throws -> [String: Any] {
        var data = try Firestore.Encoder().encode(couple)
        data["memberIDs"] = couple.members.map(\.id)
        return data
    }

    // MARK: 읽기

    func loadSnapshot(coupleID: String) async throws -> CoupleSnapshot {
        let ref = coupleRef(coupleID)
        let doc = try await ref.getDocument()
        guard doc.exists else { throw RepositoryError.coupleNotFound }

        var snapshot = CoupleSnapshot(couple: try doc.data(as: Couple.self))
        snapshot.anniversaries = try await fetch(Anniversary.self, in: ref)
        snapshot.places = try await fetch(SavedPlace.self, in: ref)
        snapshot.categories = Self.withDefaults(try await fetch(PlaceCategory.self, in: ref))
        snapshot.events = try await fetch(CalendarEvent.self, in: ref)
        snapshot.diaries = try await fetch(DiaryEntry.self, in: ref)
        return snapshot
    }

    private func fetch<T: CoupleDocument>(_ type: T.Type, in ref: DocumentReference) async throws -> [T] {
        let query = try await ref.collection(T.collection).getDocuments()
        return query.documents.compactMap { try? $0.data(as: T.self) }
    }

    /// 기본 카테고리는 저장하지 않고 늘 앞에 붙인다. 같은 id 로 저장된 게 있으면 그걸 쓴다.
    private static func withDefaults(_ stored: [PlaceCategory]) -> [PlaceCategory] {
        let storedIDs = Set(stored.map(\.id))
        return PlaceCategory.defaults.filter { !storedIDs.contains($0.id) } + stored
    }

    func snapshotStream(coupleID: String) -> AsyncStream<CoupleSnapshot> {
        AsyncStream { continuation in
            let ref = coupleRef(coupleID)
            let state = StreamState()
            var registrations: [ListenerRegistration] = []

            // Firestore 리스너는 메인 스레드에서 불린다
            registrations.append(ref.addSnapshotListener { doc, error in
                MainActor.assumeIsolated {
                    if let error { print("커플 구독 오류: \(error)") }
                    guard let doc, doc.exists, let couple = try? doc.data(as: Couple.self) else { return }
                    state.couple = couple
                    state.emit(to: continuation)
                }
            })

            func listen<T: CoupleDocument>(_ type: T.Type, _ assign: @escaping @MainActor ([T]) -> Void) {
                registrations.append(ref.collection(T.collection).addSnapshotListener { query, error in
                    MainActor.assumeIsolated {
                        if let error { print("\(T.collection) 구독 오류: \(error)") }
                        guard let query else { return }
                        assign(query.documents.compactMap { try? $0.data(as: T.self) })
                        state.emit(to: continuation)
                    }
                })
            }

            listen(Anniversary.self) { state.parts.anniversaries = $0 }
            listen(SavedPlace.self) { state.parts.places = $0 }
            listen(PlaceCategory.self) { state.parts.categories = Self.withDefaults($0) }
            listen(CalendarEvent.self) { state.parts.events = $0 }
            listen(DiaryEntry.self) { state.parts.diaries = $0 }

            let box = RegistrationBox(registrations)
            continuation.onTermination = { _ in
                Task { @MainActor in box.removeAll() }
            }
        }
    }

    func coupleID(forUser userID: String) async throws -> String? {
        let doc = try await userRef(userID).getDocument()
        return doc.data()?["coupleID"] as? String
    }

    // MARK: 쓰기
    //
    // 쓰기는 서버 응답을 기다리지 않는다. Firestore 가 기기에 먼저 반영(리스너에도 바로 들어온다)하고
    // 연결되면 보내 주므로, 오프라인에서도 화면이 멈추지 않는다. 서버 확인은 뒤에서 기다리고 실패는 로그로 남긴다.

    func saveCouple(_ couple: Couple) async throws {
        let ref = coupleRef(couple.id)
        let data = try coupleData(couple)
        inBackground("커플 저장") { try await ref.setData(data, merge: true) }
    }

    func upsert<T: CoupleDocument>(_ item: T, coupleID: String) async throws {
        let ref = coupleRef(coupleID).collection(T.collection).document(item.id)
        let data = try Firestore.Encoder().encode(item)
        inBackground("\(T.collection) 저장") { try await ref.setData(data) }
    }

    func delete<T: CoupleDocument>(_ type: T.Type, id: String, coupleID: String) async throws {
        let ref = coupleRef(coupleID).collection(T.collection).document(id)
        inBackground("\(T.collection) 삭제") { try await ref.delete() }
    }

    private func inBackground(_ label: String, _ write: @escaping () async throws -> Void) {
        Task {
            do {
                try await write()
            } catch {
                print("\(label) 실패: \(error)")
            }
        }
    }

    // MARK: 커플 만들기 / 합류 (서버 응답을 기다린다 — 온보딩은 연결이 있어야 한다)

    func createCouple(owner: Partner, startDate: Date) async throws -> Couple {
        var code = InviteCode.generate()
        for _ in 0..<5 {
            if !(try await inviteRef(code).getDocument().exists) { break }
            code = InviteCode.generate()
        }

        let ref = db.collection("couples").document()
        let couple = Couple(
            id: ref.documentID,
            inviteCode: code,
            members: [owner],
            startDate: startDate,
            theme: .default,
            cat: CatState()
        )

        let batch = db.batch()
        batch.setData(try coupleData(couple), forDocument: ref)
        batch.setData(["coupleID": couple.id], forDocument: userRef(owner.id))
        batch.setData(["coupleID": couple.id, "createdAt": FieldValue.serverTimestamp()], forDocument: inviteRef(code))
        try await batch.commit()
        return couple
    }

    func joinCouple(inviteCode: String, partner: Partner) async throws -> Couple {
        let code = InviteCode.normalize(inviteCode)
        let invite = try await inviteRef(code).getDocument()
        guard let coupleID = invite.data()?["coupleID"] as? String else {
            throw RepositoryError.invalidInviteCode
        }

        // 아직 멤버가 아니라 커플 문서를 읽을 수 없으니, 읽지 않고 나를 추가한다.
        // 규칙이 "1명 → 2명, 나만 추가" 일 때만 허락하므로 이미 꽉 찬 커플이면 여기서 거절된다.
        do {
            try await coupleRef(coupleID).updateData([
                "memberIDs": FieldValue.arrayUnion([partner.id]),
                "members": FieldValue.arrayUnion([try Firestore.Encoder().encode(partner)]),
            ])
        } catch let error as NSError where error.domain == FirestoreErrorDomain && error.code == Self.permissionDenied {
            throw RepositoryError.coupleAlreadyFull
        }

        try await userRef(partner.id).setData(["coupleID": coupleID])
        return try await coupleRef(coupleID).getDocument().data(as: Couple.self)
    }

    /// Firestore 의 permission-denied 오류 코드 (gRPC 상태 코드 7)
    private static let permissionDenied = 7
}

// MARK: - 구독 상태

/// 리스너 여러 개가 따로따로 도착하는 조각을 모아 하나의 스냅샷으로 내보낸다.
@MainActor
private final class StreamState {
    var couple: Couple?
    /// couple 을 뺀 나머지 조각. couple 자리는 emit 할 때 채운다.
    var parts = CoupleSnapshot(couple: Couple(
        id: "", inviteCode: "", members: [], startDate: .now, theme: .default, cat: CatState()
    ))

    func emit(to continuation: AsyncStream<CoupleSnapshot>.Continuation) {
        // 커플 문서가 도착하기 전에는 내보내지 않는다
        guard let couple else { return }
        var snapshot = parts
        snapshot.couple = couple
        continuation.yield(snapshot)
    }
}

@MainActor
private final class RegistrationBox {
    private var registrations: [ListenerRegistration]
    init(_ registrations: [ListenerRegistration]) { self.registrations = registrations }
    func removeAll() {
        registrations.forEach { $0.remove() }
        registrations.removeAll()
    }
}
