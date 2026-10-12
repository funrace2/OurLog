//
//  AuthService.swift
//  OurLog
//
//  로그인. Apple 로그인으로 사용자를 식별하고, 커플 연결은 초대코드로 한다.
//

import Foundation
import AuthenticationServices

nonisolated struct AuthUser: Codable, Hashable, Sendable {
    let id: String
    /// Apple 은 최초 1회만 이름을 주기 때문에 받아 두었다가 저장해 둔다.
    var displayName: String?
}

nonisolated enum AuthError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: "로그인을 취소했어요."
        case .failed(let message): message
        }
    }
}

@MainActor
protocol AuthService {
    var currentUser: AuthUser? { get }
    func signIn() async throws -> AuthUser
    func signOut()
}

// MARK: - 로컬(개발용)

/// Apple 로그인 자격이 준비되기 전까지 쓰는 구현.
/// 기기 안에서만 유효한 고정 id 를 만들어 준다.
@MainActor
final class LocalAuthService: AuthService {
    private let storageKey = "ourlog.local.user"

    private(set) var currentUser: AuthUser? {
        didSet {
            guard let currentUser else {
                UserDefaults.standard.removeObject(forKey: storageKey)
                return
            }
            UserDefaults.standard.set(try? JSONEncoder().encode(currentUser), forKey: storageKey)
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: data) {
            currentUser = user
        }
    }

    func signIn() async throws -> AuthUser {
        if let currentUser { return currentUser }
        let user = AuthUser(id: "local-" + UUID().uuidString, displayName: nil)
        currentUser = user
        return user
    }

    func signOut() {
        currentUser = nil
    }
}

// MARK: - Apple 로그인

/// 실제 Apple 로그인.
///
/// 쓰려면 먼저:
///  1. Xcode > 타겟 > Signing & Capabilities 에서 "Sign in with Apple" 추가
///  2. AppEnvironment 의 `useAppleSignIn` 을 true 로
///
/// Firebase 를 붙인 뒤에는 여기서 받은 identityToken 을 그대로
/// `Auth.auth().signIn(with: OAuthProvider.appleCredential(...))` 에 넘기면 된다.
@MainActor
final class AppleAuthService: NSObject, AuthService {
    private let storageKey = "ourlog.apple.user"
    private var continuation: CheckedContinuation<AuthUser, Error>?

    private(set) var currentUser: AuthUser? {
        didSet {
            guard let currentUser else {
                UserDefaults.standard.removeObject(forKey: storageKey)
                return
            }
            UserDefaults.standard.set(try? JSONEncoder().encode(currentUser), forKey: storageKey)
        }
    }

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: data) {
            currentUser = user
        }
    }

    func signIn() async throws -> AuthUser {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func signOut() {
        currentUser = nil
    }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in self.finish(.failure(AuthError.failed("로그인 정보를 읽지 못했어요."))) }
            return
        }

        let name = credential.fullName.flatMap {
            PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
        }
        let user = AuthUser(
            id: credential.user,
            displayName: (name?.isEmpty == false) ? name : nil
        )

        Task { @MainActor in
            // Apple 은 이름을 최초 1회만 주므로, 이미 저장해 둔 이름이 있으면 지키고 본다.
            var resolved = user
            if resolved.displayName == nil { resolved.displayName = self.currentUser?.displayName }
            self.currentUser = resolved
            self.finish(.success(resolved))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let resolved: Error = (error as? ASAuthorizationError)?.code == .canceled
            ? AuthError.cancelled
            : AuthError.failed(error.localizedDescription)
        Task { @MainActor in self.finish(.failure(resolved)) }
    }

    private func finish(_ result: Result<AuthUser, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return scene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}
