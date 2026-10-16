//
//  OurLogWidget.swift
//  OurLogWidget
//
//  홈 화면 · 잠금 화면 위젯. 앱이 App Group 에 써 둔 WidgetSnapshot 만 읽는다.
//  디데이는 저장된 날짜로 그날그날 계산하므로, 자정마다 새 항목이 보이도록 타임라인을 잡는다.
//

import WidgetKit
import SwiftUI

// MARK: - 타임라인

nonisolated struct DdayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

nonisolated struct DdayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DdayEntry {
        DdayEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (DdayEntry) -> Void) {
        // 위젯 고르는 화면에서는 데이터가 없어도 예시를 보여준다
        let snapshot = WidgetSnapshot.load() ?? (context.isPreview ? .preview : nil)
        completion(DdayEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DdayEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current

        // 지금 + 앞으로 7일의 자정마다 한 장씩. 앱이 데이터를 바꾸면 그때 다시 만들어진다.
        var entries = [DdayEntry(date: .now, snapshot: snapshot)]
        let today = cal.startOfDay(for: .now)
        for offset in 1...7 {
            if let midnight = cal.date(byAdding: .day, value: offset, to: today) {
                entries.append(DdayEntry(date: midnight, snapshot: snapshot))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - 위젯

struct OurLogWidget: Widget {
    let kind = "OurLogDday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DdayProvider()) { entry in
            DdayWidgetView(entry: entry)
        }
        .configurationDisplayName("우리 디데이")
        .description("만난 지 며칠째인지와 다가오는 기념일, 우리 고양이를 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - 화면

struct DdayWidgetView: View {
    let entry: DdayEntry

    @Environment(\.widgetFamily) private var family

    private var palette: ThemePalette { (entry.snapshot?.theme ?? .default).palette }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemMedium: MediumView(snapshot: snapshot, date: entry.date)
                case .accessoryCircular: CircularView(snapshot: snapshot, date: entry.date)
                case .accessoryRectangular: RectangularView(snapshot: snapshot, date: entry.date)
                default: SmallView(snapshot: snapshot, date: entry.date)
                }
            } else {
                EmptyWidgetView(isAccessory: family == .accessoryCircular || family == .accessoryRectangular)
            }
        }
        .environment(\.palette, palette)
        .containerBackground(for: .widget) { palette.paper }
    }
}

/// 작은 위젯: 디데이 숫자 + 고양이
private struct SmallView: View {
    let snapshot: WidgetSnapshot
    let date: Date
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("우리 만난 지")
                .font(.hand(17))
                .foregroundStyle(palette.inkSoft)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(snapshot.daysTogether(on: date))")
                    .font(.hand(44, bold: true))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("일")
                    .font(.hand(20, bold: true))
            }
            .foregroundStyle(palette.pen)

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                if let next = snapshot.nextUpcoming(on: date) {
                    Text(dLabel(next.item.title, next.daysLeft))
                        .font(.hand(15))
                        .foregroundStyle(palette.ink)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                CatSprite(snapshot: snapshot)
                    .frame(width: 58, height: 58)
            }
        }
    }
}

/// 중간 위젯: 고양이 + 이름 + 디데이 + 다음 기념일
private struct MediumView: View {
    let snapshot: WidgetSnapshot
    let date: Date
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                CatSprite(snapshot: snapshot)
                    .frame(width: 96, height: 96)
                Text(snapshot.catName)
                    .font(.hand(15))
                    .foregroundStyle(palette.inkSoft)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(names)
                    .font(.hand(17))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("만난 지")
                        .font(.hand(18))
                        .foregroundStyle(palette.inkSoft)
                    Text("\(snapshot.daysTogether(on: date))")
                        .font(.hand(40, bold: true))
                        .foregroundStyle(palette.pen)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("일")
                        .font(.hand(20, bold: true))
                        .foregroundStyle(palette.pen)
                }

                if let next = snapshot.nextUpcoming(on: date) {
                    Text(dLabel("\(next.item.emoji) \(next.item.title)", next.daysLeft))
                        .font(.hand(17))
                        .foregroundStyle(palette.ink)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .sketchBox(seed: 61, fill: palette.card, roughness: 1.1, lineWidth: 1.4)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var names: String {
        guard let partner = snapshot.partner else { return "\(snapshot.me.emoji) \(snapshot.me.name)" }
        return "\(snapshot.me.emoji) \(snapshot.me.name) ♥ \(partner.emoji) \(partner.name)"
    }
}

/// 잠금 화면 원형
private struct CircularView: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Image(systemName: "heart.fill").font(.system(size: 10))
                Text("\(snapshot.daysTogether(on: date))")
                    .font(.hand(22, bold: true))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(4)
        }
    }
}

/// 잠금 화면 직사각형
private struct RectangularView: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("우리 만난 지 \(snapshot.daysTogether(on: date))일")
                .font(.hand(19, bold: true))
            if let next = snapshot.nextUpcoming(on: date) {
                Text(dLabel(next.item.title, next.daysLeft))
                    .font(.hand(16))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 아직 앱에서 커플이 연결되지 않았을 때
private struct EmptyWidgetView: View {
    let isAccessory: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        if isAccessory {
            Text("OurLog").font(.hand(16, bold: true))
        } else {
            VStack(spacing: 4) {
                PixelSpriteView(sprite: CatSprites.idle(.egg))
                    .frame(width: 52, height: 52)
                Text("앱에서 둘을\n연결해 주세요")
                    .font(.hand(15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.inkSoft)
            }
        }
    }
}

/// 도트 고양이 (착용 아이템 포함, 위젯은 움직이지 않는다)
private struct CatSprite: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        PixelSpriteView(sprite: CatComposer.compose(
            stage: snapshot.catStage,
            accessoryIDs: snapshot.accessories,
            blink: false
        ))
    }
}

/// "100일 D-3", 오늘이면 "100일 오늘!"
private func dLabel(_ title: String, _ daysLeft: Int) -> String {
    daysLeft == 0 ? "\(title) 오늘!" : "\(title) D-\(daysLeft)"
}

// MARK: - 예시 데이터

extension WidgetSnapshot {
    nonisolated static let preview = WidgetSnapshot(
        startDate: Calendar.current.date(byAdding: .day, value: -122, to: .now) ?? .now,
        me: .init(name: "나", emoji: "🐣"),
        partner: .init(name: "너", emoji: "🐰"),
        catName: "모찌",
        catStage: .teen,
        accessoryIDs: ["head": "acc-ribbon"],
        upcoming: [.init(title: "200일", emoji: "💗", date: Calendar.current.date(byAdding: .day, value: 78, to: .now) ?? .now)],
        theme: .default
    )
}

#Preview(as: .systemSmall) {
    OurLogWidget()
} timeline: {
    DdayEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    OurLogWidget()
} timeline: {
    DdayEntry(date: .now, snapshot: .preview)
}
