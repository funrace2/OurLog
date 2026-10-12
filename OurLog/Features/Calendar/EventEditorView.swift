//
//  EventEditorView.swift
//  OurLog
//
//  일정 추가 / 수정.
//

import SwiftUI

struct EventEditorView: View {
    /// nil 이면 새 일정
    let event: CalendarEvent?
    let defaultDate: Date

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var startDate = Date.now
    @State private var endDate = Date.now
    @State private var isAllDay = true
    @State private var memo = ""
    @State private var placeID: String?
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { event != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        CuteCard {
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("무엇을 하나요?")
                                TextField("데이트, 기념일 저녁, 영화…", text: $title)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .background(palette.surfaceAlt, in: .rect(cornerRadius: 14))
                            }
                        }

                        CuteCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Toggle(isOn: $isAllDay) {
                                    Text("하루 종일")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(palette.textPrimary)
                                }
                                .tint(palette.primary)

                                DatePicker(
                                    "시작",
                                    selection: $startDate,
                                    displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                                )
                                .font(.system(size: 15, weight: .medium, design: .rounded))

                                DatePicker(
                                    "종료",
                                    selection: $endDate,
                                    in: startDate...,
                                    displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                                )
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                            }
                        }

                        placeSection

                        CuteCard {
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("메모")
                                TextField("준비물이나 하고 싶은 말", text: $memo, axis: .vertical)
                                    .font(.system(size: 15, design: .rounded))
                                    .lineLimit(3...6)
                            }
                        }

                        Button(isEditing ? "수정하기" : "추가하기") { save() }
                            .buttonStyle(.soft)
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                        if isEditing {
                            Button("일정 삭제", role: .destructive) { showDeleteConfirm = true }
                                .buttonStyle(.softPlain)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isEditing ? "일정 수정" : "새 일정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            .confirmationDialog("이 일정을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    if let event { Task { await app.deleteEvent(id: event.id) } }
                    dismiss()
                }
            }
            .onAppear(perform: load)
        }
    }

    private var placeSection: some View {
        CuteCard {
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("장소 연결 (선택)")

                if app.places.isEmpty {
                    Text("저장한 장소가 있으면 여기에 연결할 수 있어요")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(app.places) { place in
                                let isSelected = placeID == place.id
                                Button {
                                    placeID = isSelected ? nil : place.id
                                } label: {
                                    Text(place.name)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(isSelected ? .white : palette.textPrimary)
                                        .lineLimit(1)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(isSelected ? palette.primary : palette.surfaceAlt, in: .capsule)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(palette.textSecondary)
    }

    private func load() {
        if let event {
            title = event.title
            startDate = event.startDate
            endDate = event.endDate
            isAllDay = event.isAllDay
            memo = event.memo
            placeID = event.placeID
        } else {
            startDate = defaultDate
            endDate = defaultDate
        }
    }

    private func save() {
        guard let userID = app.me?.id else { return }

        let updated = CalendarEvent(
            id: event?.id ?? UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: max(startDate, endDate),
            isAllDay: isAllDay,
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            createdBy: event?.createdBy ?? userID,
            placeID: placeID
        )

        Task {
            if event == nil {
                await app.addEvent(updated)
            } else {
                await app.updateEvent(updated)
            }
        }
        dismiss()
    }
}
