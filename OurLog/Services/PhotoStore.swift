//
//  PhotoStore.swift
//  OurLog
//
//  데이트 일기 사진 저장소.
//
//  사진은 늘 기기 안(Documents/DiaryPhotos)에 캐시하고, remote 가 연결되어 있으면
//  저장할 때 올리고 기기에 없는 사진(상대방이 올린 것)은 처음 볼 때 내려받는다.
//  remote 가 없으면 기기 안에서만 동작한다 (Firebase Storage 를 켜기 전).
//

import UIKit
import Observation

/// 사진을 주고받는 원격 저장소. Firebase Storage 구현은 FirebasePhotoRemote.
@MainActor
protocol PhotoRemote {
    func upload(_ data: Data, id: String) async throws
    func download(id: String) async throws -> Data
    func delete(id: String) async throws
}

@MainActor
@Observable
final class PhotoStore {
    static let shared = PhotoStore()

    /// 커플이 연결되면 AppState 가 넣어 준다.
    @ObservationIgnored var remote: PhotoRemote?

    /// 내려받기가 끝난 사진 id. 이 값이 바뀌면 사진을 보여주던 화면이 다시 그려진다.
    private var downloaded: Set<String> = []

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let cache = NSCache<NSString, UIImage>()
    @ObservationIgnored private var inFlight: Set<String> = []

    private init() {
        directory = URL.documentsDirectory.appending(path: "DiaryPhotos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(for id: String) -> URL {
        directory.appending(path: "\(id).jpg")
    }

    /// 저장하고 photoID 를 돌려준다. 업로드는 뒤에서 이어진다.
    @discardableResult
    func save(_ image: UIImage) -> String? {
        // 원본 그대로 두면 용량이 커서, 긴 변 기준 1600pt 로 줄여 저장한다.
        let resized = image.downscaled(maxDimension: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }

        let id = UUID().uuidString
        do {
            try data.write(to: url(for: id), options: .atomic)
        } catch {
            return nil
        }
        cache.setObject(resized, forKey: id as NSString)

        if let remote {
            Task {
                do {
                    try await remote.upload(data, id: id)
                } catch {
                    print("사진 업로드 실패 \(id): \(error)")
                }
            }
        }
        return id
    }

    /// 기기에 있으면 바로 돌려주고, 없으면 내려받기를 시작하고 nil 을 돌려준다.
    /// 내려받기가 끝나면 이 메서드를 부른 화면이 다시 그려진다.
    func image(for id: String) -> UIImage? {
        _ = downloaded.contains(id)   // 관찰 등록

        if let cached = cache.object(forKey: id as NSString) { return cached }
        if let image = UIImage(contentsOfFile: url(for: id).path) {
            cache.setObject(image, forKey: id as NSString)
            return image
        }

        fetch(id)
        return nil
    }

    private func fetch(_ id: String) {
        guard let remote, !inFlight.contains(id) else { return }
        inFlight.insert(id)
        Task {
            defer { inFlight.remove(id) }
            guard let data = try? await remote.download(id: id) else { return }
            try? data.write(to: url(for: id), options: .atomic)
            downloaded.insert(id)
        }
    }

    func delete(_ id: String) {
        cache.removeObject(forKey: id as NSString)
        try? FileManager.default.removeItem(at: url(for: id))
        if let remote {
            Task { try? await remote.delete(id: id) }
        }
    }
}

extension UIImage {
    /// 긴 변이 maxDimension 을 넘지 않도록 비율을 지켜 줄인다.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }

        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
