//
//  NotificationService.swift
//  OurLog
//
//  기념일 알림. 기기 로컬 알림으로 예약한다.
//  (상대방 행동을 알리는 푸시는 Firebase Cloud Messaging 을 붙일 때 추가)
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    /// 이 앱이 만든 기념일 알림임을 표시하는 접두어. 재예약할 때 이것만 골라 지운다.
    private let prefix = "ourlog.anniversary."

    private init() {}

    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// 기념일 목록 전체를 다시 예약한다. 목록이 바뀔 때마다 통째로 갈아끼우는 방식.
    func reschedule(for anniversaries: [Anniversary]) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let mine = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: mine)

        guard await requestAuthorizationIfNeeded() else { return }

        for anniversary in anniversaries {
            for daysBefore in anniversary.notifyDaysBefore {
                guard let request = request(for: anniversary, daysBefore: daysBefore) else { continue }
                try? await center.add(request)
            }
        }
    }

    private func request(for anniversary: Anniversary, daysBefore: Int) -> UNNotificationRequest? {
        let cal = Calendar.dday
        guard let fireDay = cal.date(byAdding: .day, value: -daysBefore, to: anniversary.nextOccurrence) else {
            return nil
        }

        // 오전 9시에 알린다.
        var comps = cal.dateComponents([.year, .month, .day], from: fireDay)
        comps.hour = 9
        comps.minute = 0

        guard let fireDate = cal.date(from: comps), fireDate > .now else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "\(anniversary.emoji) \(anniversary.title)"
        content.body = daysBefore == 0
            ? "오늘이에요! 둘만의 하루를 남겨 보세요."
            : "\(daysBefore)일 남았어요. 슬슬 준비해 볼까요?"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )

        return UNNotificationRequest(
            identifier: "\(prefix)\(anniversary.id).\(daysBefore)",
            content: content,
            trigger: trigger
        )
    }
}
