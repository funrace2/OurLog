//
//  FirestorePhotoRemote.swift
//  OurLog
//
//  일기 사진을 Storage 대신 Firestore 문서에 직접 넣는다. (Blaze 요금제 없이 사진을 공유하기 위해)
//
//  couples/{coupleID}/photos/{photoID} = { data: <JPEG 바이트>, createdAt }
//
//  Firestore 문서는 1MiB 를 넘을 수 없어서, 긴 변 1000px 로 줄이고
//  그래도 크면 화질을 낮춰 가며 900KB 안쪽으로 맞춘다 (보통 장당 100~250KB).
//  무료 요금제 Firestore 용량 1GiB 기준으로 대략 수천 장까지 들어간다.
//  규칙은 firestore.rules 의 커플 하위 컬렉션 규칙이 그대로 적용된다.
//

import UIKit
import FirebaseFirestore

@MainActor
final class FirestorePhotoRemote: PhotoRemote {
    private let photos: CollectionReference

    private let maxDimension: CGFloat = 1000
    private let maxBytes = 900 * 1024

    init(coupleID: String) {
        photos = Firestore.firestore().collection("couples").document(coupleID).collection("photos")
    }

    func upload(_ data: Data, id: String) async throws {
        guard let compact = compress(data) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey: "사진을 줄이지 못했어요."])
        }
        try await photos.document(id).setData([
            "data": compact,
            "createdAt": FieldValue.serverTimestamp(),
        ])
    }

    func download(id: String) async throws -> Data {
        let doc = try await photos.document(id).getDocument()
        guard let data = doc.data()?["data"] as? Data else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return data
    }

    func delete(id: String) async throws {
        try await photos.document(id).delete()
    }

    /// 문서 크기 제한 안으로 들어올 때까지 줄인다.
    private func compress(_ data: Data) -> Data? {
        guard let image = UIImage(data: data)?.downscaled(maxDimension: maxDimension) else { return nil }
        for quality in stride(from: 0.75, through: 0.3, by: -0.15) {
            if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= maxBytes {
                return jpeg
            }
        }
        return nil
    }
}
