//
//  RemoteImage.swift
//  OurLog
//
//  웹 이미지를 받아 화면 크기에 맞게 줄여서 보여준다.
//  원본(보통 장당 1MB 안팎)은 디스크에 캐시해서 같은 사진은 다시 받지 않는다.
//

import SwiftUI
import ImageIO

@MainActor
final class RemoteImageLoader {
    static let shared = RemoteImageLoader()

    private let memory = NSCache<NSString, UIImage>()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    /// maxPixel: 긴 변 최대 픽셀
    func image(for url: URL, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(url.absoluteString)|\(Int(maxPixel))" as NSString
        if let cached = memory.object(forKey: key) { return cached }

        guard let (data, _) = try? await session.data(from: url),
              let image = Self.downsample(data, maxPixel: maxPixel)
        else { return nil }
        memory.setObject(image, forKey: key)
        return image
    }

    /// 큰 원본을 통째로 메모리에 풀지 않고 바로 작은 크기로 디코딩한다.
    private nonisolated static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// 받는 동안은 종이색 칸, 실패하면 빈 그림 표시.
struct RemoteImage: View {
    let url: URL
    var maxPixel: CGFloat = 900
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var failed = false
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                palette.paperDeep
                if failed {
                    Image(systemName: "photo")
                        .foregroundStyle(palette.inkSoft)
                } else {
                    ProgressView().tint(palette.inkSoft)
                }
            }
        }
        .task(id: url) {
            image = await RemoteImageLoader.shared.image(for: url, maxPixel: maxPixel)
            failed = image == nil
        }
    }
}
