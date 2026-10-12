//
//  PhotoStore.swift
//  OurLog
//
//  데이트 일기 사진 저장소.
//  지금은 앱 내부 디렉터리에 JPEG 로 넣고, Firebase Storage 를 붙이면
//  같은 photoID 를 Storage 경로로 쓰면서 업로드/다운로드만 바꾸면 된다.
//

import UIKit

@MainActor
final class PhotoStore {
    static let shared = PhotoStore()

    private let directory: URL
    private var cache = NSCache<NSString, UIImage>()

    private init() {
        directory = URL.documentsDirectory.appending(path: "DiaryPhotos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(for id: String) -> URL {
        directory.appending(path: "\(id).jpg")
    }

    /// 저장하고 photoID 를 돌려준다.
    @discardableResult
    func save(_ image: UIImage) -> String? {
        // 원본 그대로 두면 용량이 커서, 긴 변 기준 1600pt 로 줄여 저장한다.
        let resized = image.downscaled(maxDimension: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }

        let id = UUID().uuidString
        do {
            try data.write(to: url(for: id), options: .atomic)
            cache.setObject(resized, forKey: id as NSString)
            return id
        } catch {
            return nil
        }
    }

    func image(for id: String) -> UIImage? {
        if let cached = cache.object(forKey: id as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: url(for: id).path) else { return nil }
        cache.setObject(image, forKey: id as NSString)
        return image
    }

    func delete(_ id: String) {
        cache.removeObject(forKey: id as NSString)
        try? FileManager.default.removeItem(at: url(for: id))
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
