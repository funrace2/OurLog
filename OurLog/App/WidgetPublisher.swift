//
//  WidgetPublisher.swift
//  OurLog
//
//  앱의 커플 데이터를 위젯이 읽을 요약(WidgetSnapshot)으로 바꿔 App Group 에 써 둔다.
//

import Foundation
import WidgetKit

extension AppState {
    func publishWidget() {
        guard let couple, let me else {
            // 로그아웃했거나 아직 커플이 없으면 위젯도 비운다
            if WidgetSnapshot.load() != nil {
                WidgetSnapshot.clear()
                WidgetCenter.shared.reloadAllTimelines()
            }
            return
        }

        let summary = WidgetSnapshot(
            startDate: couple.startDate,
            me: .init(name: me.displayName, emoji: me.emoji),
            partner: partner.map { .init(name: $0.displayName, emoji: $0.emoji) },
            catName: cat.name,
            catStage: cat.stage,
            accessoryIDs: Dictionary(uniqueKeysWithValues: cat.equippedAccessories.map { ($0.key.rawValue, $0.value) }),
            upcoming: upcomingAnniversaries.prefix(6).map {
                .init(title: $0.title, emoji: $0.emoji, date: $0.nextOccurrence)
            },
            theme: theme
        )

        if summary.save() {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
