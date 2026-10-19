//
//  AppState.swift
//  OurLog
//
//  앱 전역 상태. 로그인 → 커플 연결 → 공유 데이터까지 한 군데서 들고 있는다.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppState {

    // MARK: 단계

    enum Phase: Equatable {
        /// 저장된 로그인 정보를 확인하는 중
        case loading
        /// 로그인 필요
        case signedOut
        /// 로그인은 했지만 아직 커플이 없음 (만들기 / 코드 입력)
        case needsCouple
        /// 다 준비됨
        case ready
    }

    private(set) var phase: Phase = .loading
    private(set) var user: AuthUser?
    private(set) var snapshot: CoupleSnapshot? {
        // 커플 데이터가 바뀔 때마다 위젯용 요약을 갱신한다 (내용이 같으면 아무것도 안 한다)
        didSet { publishWidget() }
    }

    /// 화면 위에 잠깐 떠오르는 알림 (애정도 획득, 진화 등)
    var toast: Toast?
    /// 진화했을 때 띄우는 축하 화면
    var evolutionToCelebrate: CatStage?
    var errorMessage: String?

    private let auth: AuthService
    private let repository: CoupleRepository
    private var streamTask: Task<Void, Never>?

    init(auth: AuthService, repository: CoupleRepository) {
        self.auth = auth
        self.repository = repository
    }

    // MARK: 파생 값

    var couple: Couple? { snapshot?.couple }
    var cat: CatState { couple?.cat ?? CatState() }
    var theme: AppTheme { couple?.theme ?? .default }
    var palette: ThemePalette { theme.palette }

    var me: Partner? {
        guard let user else { return nil }
        return couple?.member(id: user.id)
    }

    var partner: Partner? {
        guard let user else { return nil }
        return couple?.partner(otherThan: user.id)
    }

    /// 보이는 카테고리 (숨긴 기본 카테고리 제외). 기본 → 직접 만든 순서.
    var categories: [PlaceCategory] {
        let all = snapshot?.categories ?? PlaceCategory.defaults
        let defaults = all.filter(\.isDefault)
            .sorted { a, b in
                (PlaceCategory.defaults.firstIndex { $0.id == a.id } ?? 0) < (PlaceCategory.defaults.firstIndex { $0.id == b.id } ?? 0)
            }
        let custom = all.filter { !$0.isDefault }.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        return (defaults + custom).filter { $0.isHidden != true }
    }
    var places: [SavedPlace] { snapshot?.places ?? [] }
    var events: [CalendarEvent] { snapshot?.events ?? [] }
    var diaries: [DiaryEntry] {
        (snapshot?.diaries ?? []).sorted { $0.date > $1.date }
    }

    /// 직접 등록한 기념일 + 생일 + 자동 생성된 100일/주년을 합쳐 다가오는 순으로.
    var upcomingAnniversaries: [Anniversary] {
        guard let couple else { return [] }

        var all = snapshot?.anniversaries ?? []
        all += MilestoneGenerator.milestones(from: couple.startDate)
        all += couple.members.compactMap { member in
            guard let birthday = member.birthday else { return nil }
            return Anniversary(
                id: "birthday-\(member.id)",
                title: "\(member.displayName) 생일",
                date: birthday,
                kind: .birthday,
                repeatsYearly: true,
                emoji: "🎂"
            )
        }

        return all
            .filter { $0.daysRemaining >= 0 }
            .sorted { $0.daysRemaining < $1.daysRemaining }
    }

    func category(id: String) -> PlaceCategory? {
        categories.first { $0.id == id }
    }

    func place(id: String?) -> SavedPlace? {
        guard let id else { return nil }
        return places.first { $0.id == id }
    }

    // MARK: 시작

    func bootstrap() async {
        if let existing = auth.currentUser {
            user = existing
            await attachCouple(for: existing)
        } else {
            phase = .signedOut
        }
    }

    func signIn() async {
        do {
            let authenticated = try await auth.signIn()
            user = authenticated
            await attachCouple(for: authenticated)
        } catch AuthError.cancelled {
            // 사용자가 직접 취소한 것이니 조용히 넘어간다.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        streamTask?.cancel()
        streamTask = nil
        auth.signOut()
        PhotoStore.shared.remote = nil
        user = nil
        snapshot = nil
        phase = .signedOut
    }

    private func attachCouple(for user: AuthUser) async {
        do {
            guard let coupleID = try await repository.coupleID(forUser: user.id) else {
                phase = .needsCouple
                return
            }
            snapshot = try await repository.loadSnapshot(coupleID: coupleID)
            connect(coupleID: coupleID)
            phase = .ready
            await rebalanceCatIfNeeded()
            await checkInIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
            phase = .needsCouple
        }
    }

    /// 커플이 정해지면 실시간 구독과 사진 저장소를 그 커플에 연결한다.
    private func connect(coupleID: String) {
        PhotoStore.shared.remote = AppEnvironment.makePhotoRemote(coupleID: coupleID)
        observe(coupleID: coupleID)
    }

    private func observe(coupleID: String) {
        streamTask?.cancel()
        streamTask = Task { [repository] in
            for await updated in repository.snapshotStream(coupleID: coupleID) {
                guard !Task.isCancelled else { return }
                self.snapshot = updated
            }
        }
    }

    // MARK: 커플 만들기 / 연결

    func createCouple(myName: String, startDate: Date) async {
        guard let user else { return }
        do {
            let owner = Partner(id: user.id, displayName: myName)
            let couple = try await repository.createCouple(owner: owner, startDate: startDate)
            snapshot = try await repository.loadSnapshot(coupleID: couple.id)
            connect(coupleID: couple.id)
            phase = .ready
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinCouple(code: String, myName: String) async {
        guard let user else { return }
        do {
            let partner = Partner(id: user.id, displayName: myName)
            let couple = try await repository.joinCouple(inviteCode: code, partner: partner)
            snapshot = try await repository.loadSnapshot(coupleID: couple.id)
            connect(coupleID: couple.id)
            phase = .ready
            await rebalanceCatIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: 커플 설정

    func setTheme(_ theme: AppTheme) async {
        guard var couple else { return }
        couple.theme = theme
        await save(couple)
    }

    func setStartDate(_ date: Date) async {
        guard var couple else { return }
        couple.startDate = date
        await save(couple)
        await refreshNotifications()
    }

    func updateMyProfile(name: String, emoji: String, birthday: Date?) async {
        guard var couple, let user else { return }
        guard let index = couple.members.firstIndex(where: { $0.id == user.id }) else { return }
        couple.members[index].displayName = name
        couple.members[index].emoji = emoji
        couple.members[index].birthday = birthday
        await save(couple)
    }

    private func save(_ couple: Couple) async {
        // 화면에는 먼저 반영하고, 저장 결과(상대방 변경 포함)는 실시간 구독으로 다시 들어온다.
        snapshot?.couple = couple
        do {
            try await repository.saveCouple(couple)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: 고양이

    func renameCat(_ name: String) async {
        guard var couple else { return }
        couple.cat.name = name
        await save(couple)
    }

    func equip(_ accessory: CatAccessory?, slot: AccessorySlot) async {
        guard var couple else { return }
        if let accessory {
            couple.cat.equippedAccessories[slot] = accessory.id
        } else {
            couple.cat.equippedAccessories[slot] = nil
        }
        await save(couple)
    }

    func placeRoomItem(_ item: RoomItem?, slot: RoomSlot) async {
        guard var couple else { return }
        if let item {
            couple.cat.placedRoomItems[slot] = item.id
        } else {
            couple.cat.placedRoomItems[slot] = nil
        }
        await save(couple)
    }

    /// 애정도를 올리고, 단계가 올랐으면 축하 화면을 띄운다.
    func gainAffection(_ action: AffectionAction, silent: Bool = false) async {
        guard var couple else { return }
        // 오늘 이 행동으로 받을 만큼 다 받았으면 저장도 알림도 하지 않는다
        guard case .gained(let evolved) = couple.cat.gain(action) else { return }
        await save(couple)

        if let evolved {
            evolutionToCelebrate = evolved
        } else if !silent {
            toast = Toast(text: "\(action.label) +\(action.points)", emoji: "💗")
        }
    }

    /// 성장 기준이 바뀌었으면 예전 애정도를 새 기준으로 한 번 옮긴다 (단계·진행률 유지).
    /// 두 폰이 동시에 해도 같은 값에서 같은 값으로 바뀌어서 괜찮다.
    private func rebalanceCatIfNeeded() async {
        guard var couple, couple.cat.rebalanceIfNeeded() else { return }
        await save(couple)
    }

    /// 하루에 한 번 출석 애정도 — 그날 둘 중 누군가 처음 앱을 열(거나 다시 앞으로 가져올) 때.
    /// 하루 상한(오늘 받은 횟수)이 기준이다.
    func checkInIfNeeded() async {
        guard phase == .ready, var couple else { return }

        // 예전 방식(마지막 출석 날짜)으로 오늘 이미 출석했는데 오늘 횟수에는 안 남은 경우:
        // 애정도는 주지 않고 "오늘 했음"만 맞춰 둔다.
        if let last = couple.cat.lastCheckIn, Calendar.dday.isDateInToday(last),
           couple.cat.usedToday(.dailyCheckIn) == 0 {
            couple.cat.markUsedToday(.dailyCheckIn)
            await save(couple)
            return
        }

        guard case .gained(let evolved) = couple.cat.gain(.dailyCheckIn) else { return }
        couple.cat.lastCheckIn = .now
        await save(couple)

        if let evolved {
            evolutionToCelebrate = evolved
        }
    }

    // MARK: 기념일

    func addAnniversary(_ anniversary: Anniversary) async {
        await upsert(anniversary)
        await refreshNotifications()
    }

    func deleteAnniversary(id: String) async {
        await delete(Anniversary.self, id: id)
        await refreshNotifications()
    }

    func refreshNotifications() async {
        await NotificationService.shared.reschedule(for: upcomingAnniversaries)
    }

    // MARK: 장소

    func addPlace(_ place: SavedPlace) async {
        await upsert(place)
        await gainAffection(.savePlace)
    }

    func updatePlace(_ place: SavedPlace) async {
        await upsert(place)
    }

    func toggleVisited(_ place: SavedPlace) async {
        var updated = place
        updated.isVisited.toggle()
        await upsert(updated)
        if updated.isVisited {
            await gainAffection(.visitPlace)
        }
    }

    func deletePlace(id: String) async {
        await delete(SavedPlace.self, id: id)
    }

    /// 카테고리 추가·수정
    func saveCategory(_ category: PlaceCategory) async {
        await upsert(category)
    }

    /// 이 카테고리에 있는 장소 수
    func placeCount(in categoryID: String) -> Int {
        places.filter { $0.categoryID == categoryID }.count
    }

    /// 지울 때 장소들을 옮길 카테고리 (지우는 것 말고 맨 앞)
    func fallbackCategory(excluding categoryID: String) -> PlaceCategory? {
        categories.first { $0.id != categoryID }
    }

    /// 카테고리 삭제. 안에 있던 장소는 남은 첫 카테고리로 옮긴다. 마지막 하나는 지우지 않는다.
    func deleteCategory(_ category: PlaceCategory) async {
        guard let fallback = fallbackCategory(excluding: category.id) else { return }

        for place in places where place.categoryID == category.id {
            var moved = place
            moved.categoryID = fallback.id
            await upsert(moved)
        }

        if category.isDefault {
            var hidden = category
            hidden.isHidden = true
            await upsert(hidden)
        } else {
            await delete(PlaceCategory.self, id: category.id)
        }
    }

    // MARK: 일정

    func addEvent(_ event: CalendarEvent) async {
        await upsert(event)
        await gainAffection(.addEvent)
    }

    func updateEvent(_ event: CalendarEvent) async {
        await upsert(event)
    }

    func deleteEvent(id: String) async {
        await delete(CalendarEvent.self, id: id)
    }

    // MARK: 일기

    func addDiary(_ entry: DiaryEntry) async {
        await upsert(entry)
        await gainAffection(.addDiary)
    }

    func updateDiary(_ entry: DiaryEntry) async {
        await upsert(entry)
    }

    func deleteDiary(_ entry: DiaryEntry) async {
        entry.photoIDs.forEach(PhotoStore.shared.delete)
        await delete(DiaryEntry.self, id: entry.id)
    }

    // MARK: 공통 저장

    // 화면에 먼저 반영하고 저장소에 보낸다. 다시 읽어오지 않는다 —
    // Firestore 에서는 매번 서버를 왕복하게 되고, 최종 상태는 실시간 구독이 맞춰 준다.

    private func upsert<T: CoupleDocument>(_ item: T) async {
        guard let coupleID = couple?.id else { return }
        snapshot?.upsert(item)
        do {
            try await repository.upsert(item, coupleID: coupleID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete<T: CoupleDocument>(_ type: T.Type, id: String) async {
        guard let coupleID = couple?.id else { return }
        snapshot?.remove(type, id: id)
        do {
            try await repository.delete(type, id: id, coupleID: coupleID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 토스트

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var emoji: String = "💗"
}
