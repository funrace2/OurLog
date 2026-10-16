//
//  FirebasePhotoRemote.swift
//  OurLog
//
//  일기 사진을 Firebase Storage 에 올리고 내려받는다.
//  경로: couples/{coupleID}/photos/{photoID}.jpg  (규칙은 storage.rules)
//
//  ⚠️ 새 Firebase 프로젝트는 Storage 를 쓰려면 Blaze(종량제) 요금제가 필요하다.
//     켜기 전에는 AppEnvironment.useFirebaseStorage 를 false 로 두면 사진은 기기에만 남는다.
//

import Foundation
import FirebaseStorage

@MainActor
final class FirebasePhotoRemote: PhotoRemote {
    private let folder: StorageReference

    /// 일기 사진은 1600pt 로 줄여 올리므로 넉넉잡아 10MB 면 충분하다.
    private let maxDownloadSize: Int64 = 10 * 1024 * 1024

    init(coupleID: String) {
        folder = Storage.storage().reference().child("couples/\(coupleID)/photos")
    }

    func upload(_ data: Data, id: String) async throws {
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await folder.child("\(id).jpg").putDataAsync(data, metadata: metadata)
    }

    func download(id: String) async throws -> Data {
        try await folder.child("\(id).jpg").data(maxSize: maxDownloadSize)
    }

    func delete(id: String) async throws {
        try await folder.child("\(id).jpg").delete()
    }
}
