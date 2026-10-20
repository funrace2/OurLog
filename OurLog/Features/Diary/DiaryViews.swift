//
//  DiaryViews.swift
//  OurLog
//
//  데이트 일기. 사진과 함께 그날을 남긴다.
//

import SwiftUI
import PhotosUI

// MARK: - 목록

struct DiaryListView: View {
    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    if app.diaries.isEmpty {
                        CuteCard {
                            EmptyStateView(
                                title: "아직 쓴 일기가 없어요",
                                message: "오늘 있었던 일을 사진과 함께 남겨보세요"
                            )
                        }
                        .padding(20)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(app.diaries) { entry in
                                NavigationLink {
                                    DiaryDetailView(entry: entry)
                                } label: {
                                    DiaryCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
            }
            .paperTitle("데이트 일기")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditor = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                DiaryEditorView(entry: nil)
            }
        }
    }
}

// MARK: - 카드

struct DiaryCard: View {
    let entry: DiaryEntry

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette

    var body: some View {
        CuteCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if let firstPhoto = entry.photoIDs.first,
                   let image = PhotoStore.shared.image(for: firstPhoto) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 170)
                            .clipped()

                        if entry.photoIDs.count > 1 {
                            Label("\(entry.photoIDs.count)", systemImage: "photo.stack.fill")
                                .font(.hand(15, bold: true))
                                .foregroundStyle(.white)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 9)
                                .sketchBox(seed: 340, fill: .black.opacity(0.45), roughness: 1.1, lineWidth: 1.4)
                                .padding(10)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(entry.mood.emoji).font(.system(size: 18))

                        Text(entry.title)
                            .font(.hand(22, bold: true))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(app.couple?.member(id: entry.authorID)?.emoji ?? "")
                            .font(.system(size: 15))
                    }

                    if !entry.body.isEmpty {
                        Text(entry.body)
                            .font(.hand(18))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        Text(entry.date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ko_KR"))))
                            .font(.hand(15))
                            .foregroundStyle(palette.textSecondary)

                        if let place = app.place(id: entry.placeID) {
                            Chip(text: place.name, systemImage: "mappin")
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(16)
            }
        }
    }
}

// MARK: - 가로 스크롤용 작은 카드

struct DiaryThumbnail: View {
    let entry: DiaryEntry

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let firstPhoto = entry.photoIDs.first,
                   let image = PhotoStore.shared.image(for: firstPhoto) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    palette.primarySoft
                    Text(entry.mood.emoji).font(.system(size: 32))
                }
            }
            .frame(width: 118, height: 100)
            .clipShape(.rect(cornerRadius: 16))

            Text(entry.title)
                .font(.hand(16, bold: true))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)

            Text(entry.date.formatted(.dateTime.month().day().locale(Locale(identifier: "ko_KR"))))
                .font(.hand(14))
                .foregroundStyle(palette.textSecondary)
        }
        .frame(width: 118)
    }
}

// MARK: - 상세

struct DiaryDetailView: View {
    let entry: DiaryEntry

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var openedPlace: SavedPlace?

    var body: some View {
        ZStack {
            CuteBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !entry.photoIDs.isEmpty {
                        TabView {
                            ForEach(entry.photoIDs, id: \.self) { photoID in
                                if let image = PhotoStore.shared.image(for: photoID) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 280)
                        .clipShape(.rect(cornerRadius: 24))
                    }

                    CuteCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Text(entry.mood.emoji).font(.system(size: 26))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(.hand(27, bold: true))
                                        .foregroundStyle(palette.textPrimary)
                                    Text(entry.date.formatted(.dateTime.year().month().day().weekday(.wide).locale(Locale(identifier: "ko_KR"))))
                                        .font(.hand(16))
                                        .foregroundStyle(palette.textSecondary)
                                }
                            }

                            if let place = app.place(id: entry.placeID) {
                                Button { openedPlace = place } label: {
                                    Chip(text: place.name, systemImage: "mappin.and.ellipse")
                                }
                                .buttonStyle(.plain)
                            }

                            if !entry.body.isEmpty {
                                Text(entry.body)
                                    .font(.hand(20))
                                    .foregroundStyle(palette.textPrimary)
                                    .lineSpacing(4)
                            }

                            Text("\(app.couple?.member(id: entry.authorID)?.displayName ?? "누군가") 님이 씀")
                                .font(.hand(15))
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                }
                .padding(20)
            }
        }
        .paperTitle("일기")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("수정", systemImage: "pencil") { showEditor = true }
                    Button("삭제", systemImage: "trash", role: .destructive) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            DiaryEditorView(entry: entry)
        }
        .sheet(item: $openedPlace) { PlaceDetailView(place: $0) }
        .confirmationDialog("이 일기를 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                Task { await app.deleteDiary(entry) }
                dismiss()
            }
        }
    }
}

// MARK: - 작성 / 수정

struct DiaryEditorView: View {
    /// nil 이면 새 일기
    let entry: DiaryEntry?

    @Environment(AppState.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bodyText = ""
    @State private var date = Date.now
    @State private var mood: DiaryEntry.Mood = .happy
    @State private var placeID: String?
    @State private var photoIDs: [String] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false

    var body: some View {
        NavigationStack {
            ZStack {
                CuteBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        photoSection
                        moodSection

                        CuteCard {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 8) {
                                    fieldLabel("제목")
                                    TextField("오늘 하루를 한 줄로", text: $title)
                                        .font(.hand(22))
                                        .sketchField()
                                }

                                DatePicker("날짜", selection: $date, displayedComponents: .date)
                                    .font(.hand(20))
                            }
                        }

                        CuteCard {
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("내용")
                                TextField("어떤 하루였나요?", text: $bodyText, axis: .vertical)
                                    .font(.hand(20))
                                    .lineLimit(6...14)
                            }
                        }

                        placeSection

                        Button(entry == nil ? "일기 남기기" : "수정하기") { save() }
                            .buttonStyle(.soft)
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(20)
                }
            }
            .paperTitle(entry == nil ? "새 일기" : "일기 수정")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ToolbarTextButton("취소") { dismiss() }
                }
            }
            .onAppear(perform: load)
            .onChange(of: pickerItems) { _, newItems in
                Task { await loadPhotos(newItems) }
            }
        }
    }

    // MARK: 사진

    private var photoSection: some View {
        CuteCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    fieldLabel("사진")
                    Spacer()
                    if isLoadingPhotos { ProgressView().controlSize(.small) }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 9, matching: .images) {
                            VStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                Text("추가")
                                    .font(.hand(15, bold: true))
                            }
                            .foregroundStyle(palette.primary)
                            .frame(width: 84, height: 84)
                            .sketchBox(seed: 354, fill: palette.primarySoft, roughness: 1.3, lineWidth: 1.6)
                        }

                        ForEach(photoIDs, id: \.self) { photoID in
                            if let image = PhotoStore.shared.image(for: photoID) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(.rect(cornerRadius: 16))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            remove(photoID)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 17))
                                                .foregroundStyle(.white, .black.opacity(0.5))
                                        }
                                        .padding(4)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoadingPhotos = true
        defer {
            isLoadingPhotos = false
            pickerItems = []
        }

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let photoID = PhotoStore.shared.save(image)
            else { continue }
            photoIDs.append(photoID)
        }
    }

    private func remove(_ photoID: String) {
        photoIDs.removeAll { $0 == photoID }
        // 저장 전에 뺀 사진은 바로 지운다. 이미 저장된 일기의 사진은 저장 시점에 정리된다.
        if entry?.photoIDs.contains(photoID) != true {
            PhotoStore.shared.delete(photoID)
        }
    }

    // MARK: 기분

    private var moodSection: some View {
        CuteCard {
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("오늘 기분")

                HStack(spacing: 8) {
                    ForEach(DiaryEntry.Mood.allCases) { option in
                        let isSelected = mood == option

                        Button {
                            withAnimation(.snappy) { mood = option }
                        } label: {
                            VStack(spacing: 3) {
                                Text(option.emoji).font(.system(size: 22))
                                Text(option.label)
                                    .font(.hand(12, bold: true))
                                    .foregroundStyle(isSelected ? palette.primary : palette.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .sketchBox(seed: 361, fill: isSelected ? palette.primarySoft : .clear, roughness: 1.3, lineWidth: 1.6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 장소

    private var placeSection: some View {
        PlaceLinkField(
            title: "어디에서? (선택)",
            emptyMessage: "지도에서 장소를 저장하면 여기에 연결할 수 있어요",
            placeID: $placeID
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.hand(18, bold: true))
            .foregroundStyle(palette.textSecondary)
    }

    // MARK: 저장

    private func load() {
        guard let entry else { return }
        title = entry.title
        bodyText = entry.body
        date = entry.date
        mood = entry.mood
        placeID = entry.placeID
        photoIDs = entry.photoIDs
    }

    private func save() {
        guard let userID = app.me?.id else { return }

        // 수정하면서 뺀 사진은 여기서 파일까지 지운다.
        if let entry {
            for removed in entry.photoIDs where !photoIDs.contains(removed) {
                PhotoStore.shared.delete(removed)
            }
        }

        let updated = DiaryEntry(
            id: entry?.id ?? UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespaces),
            body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            mood: mood,
            photoIDs: photoIDs,
            placeID: placeID,
            authorID: entry?.authorID ?? userID,
            createdAt: entry?.createdAt ?? .now
        )

        Task {
            if entry == nil {
                await app.addDiary(updated)
            } else {
                await app.updateDiary(updated)
            }
        }
        dismiss()
    }
}
