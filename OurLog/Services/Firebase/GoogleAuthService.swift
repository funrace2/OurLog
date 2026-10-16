//
//  GoogleAuthService.swift
//  OurLog
//
//  Google 계정으로 로그인하고, 그 자격으로 Firebase Auth 에 들어간다.
//  (유료 개발자 계정이 생기면 같은 Firebase 계정에 Apple 로그인을 연결할 수 있다 — uid 가 유지된다)
//

import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@MainActor
final class GoogleAuthService: AuthService {

    var currentUser: AuthUser? {
        Auth.auth().currentUser.map { AuthUser(id: $0.uid, displayName: $0.displayName) }
    }

    func signIn() async throws -> AuthUser {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.failed("Firebase 설정을 찾을 수 없어요.")
        }
        guard let presenter = Self.topViewController() else {
            throw AuthError.failed("로그인 화면을 띄울 수 없어요.")
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch let error as GIDSignInError where error.code == .canceled {
            throw AuthError.cancelled
        } catch {
            throw AuthError.failed("Google 로그인에 실패했어요. (\(error.localizedDescription))")
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.failed("Google 로그인 정보를 읽지 못했어요.")
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return AuthUser(id: authResult.user.uid, displayName: authResult.user.displayName)
    }

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    /// 지금 맨 앞에 떠 있는 화면 (Google 로그인 시트를 이 위에 띄운다)
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
