# OurLog 연동 준비 메모

지금 앱은 **키 없이 그대로 빌드·실행된다.** 로그인은 기기 로컬 계정, 데이터는 기기 안 JSON,
지도는 MapKit으로 동작한다. 아래 셋을 붙이면 실제 공유 앱이 된다.

교체 지점은 전부 [AppEnvironment.swift](OurLog/App/AppEnvironment.swift) 한 파일에 모여 있다.

---

## 1. Apple 로그인

가장 먼저 하면 좋다. 유료 개발자 계정이 있으면 10분이면 끝난다.

1. Xcode > OurLog 타겟 > **Signing & Capabilities** > `+ Capability` > **Sign in with Apple**
2. `AppEnvironment.useAppleSignIn` 을 `true` 로

구현은 [AppleAuthService](OurLog/Services/AuthService.swift)에 이미 들어 있다.
Capability를 켜지 않은 채 `true` 로 바꾸면 로그인 시점에 실패하니 순서를 지킬 것.

---

## 2. Firebase

두 사람 사이의 실제 공유가 여기서 생긴다. **이걸 붙이기 전까지는 기기 간 동기화가 되지 않는다.**

### 프로젝트 만들기

1. [console.firebase.google.com](https://console.firebase.google.com) 에서 프로젝트 생성
2. iOS 앱 추가 — 번들 ID는 `gaeuni.OurLog`
3. 받은 `GoogleService-Info.plist` 를 `OurLog/` 폴더에 넣기
   (폴더에 넣으면 동기화 그룹이라 Xcode가 알아서 타겟에 포함한다)

### SDK 추가

Xcode > File > Add Package Dependencies > `https://github.com/firebase/firebase-ios-sdk`

필요한 것만 고른다:
- `FirebaseAuth` — Apple 로그인 연동
- `FirebaseFirestore` — 공유 데이터
- `FirebaseStorage` — 일기 사진
- `FirebaseMessaging` — (나중에) 상대방 활동 푸시

### 코드에서 할 일

1. `OurLogApp.swift` 의 `init()` 에서 `FirebaseApp.configure()`
2. `FirestoreCoupleRepository` 를 새로 만들어 [CoupleRepository](OurLog/Services/CoupleRepository.swift) 프로토콜을 구현
3. `AppEnvironment.makeRepository()` 가 그걸 돌려주게 변경

### Firestore 구조

프로토콜이 이미 이 구조를 전제로 설계돼 있다.

```
couples/{coupleID}                     ← Couple (멤버, 시작일, 테마, 고양이 상태)
couples/{coupleID}/anniversaries/{id}
couples/{coupleID}/places/{id}
couples/{coupleID}/categories/{id}
couples/{coupleID}/events/{id}
couples/{coupleID}/diaries/{id}

users/{userID}       → { coupleID }    ← 로그인 후 내 커플 찾기
invites/{code}       → { coupleID }    ← 초대코드로 합류
```

`CoupleDocument.collection` 이 위 하위 컬렉션 이름과 그대로 맞아떨어지므로,
`upsert` / `delete` 는 `db.collection("couples").document(id).collection(T.collection)` 한 줄로 끝난다.

`snapshotStream(coupleID:)` 은 `addSnapshotListener` 로 바꾸면 상대방 변경이 실시간으로 넘어온다.

### 보안 규칙 (최소한)

커플 멤버만 자기 커플 문서를 읽고 쓰게 막아야 한다. 대략 이런 형태:

```
match /couples/{coupleID} {
  allow read, write: if request.auth != null
    && request.auth.uid in resource.data.memberIDs;
  match /{sub}/{doc} {
    allow read, write: if request.auth != null
      && request.auth.uid in get(/databases/$(database)/documents/couples/$(coupleID)).data.memberIDs;
  }
}
```

`Couple` 에 `memberIDs: [String]` 배열을 따로 두면 규칙이 훨씬 단순해진다.
(지금은 `members: [Partner]` 뿐이라 Firestore로 옮길 때 같이 넣는 걸 권한다.)

---

## 3. 네이버 지도

### 지도 렌더링

[NAVER Cloud Platform](https://www.ncloud.com) 콘솔에서 **Maps** 서비스를 신청하고
iOS 앱 번들 ID를 등록해 Client ID를 받는다.

SDK는 SPM 또는 CocoaPods로 추가한다. **Info.plist 키 이름과 초기화 방법이 SDK 버전마다 바뀌어 왔으니
설치 직전에 현재 공식 문서를 꼭 확인할 것.**

`NMFMapView` 는 UIKit 뷰라서 SwiftUI에서 쓰려면 `UIViewRepresentable` 래퍼가 하나 필요하다.
바꿀 곳은 [PlacesMapView.swift](OurLog/Features/Map/PlacesMapView.swift) 의 `map` 프로퍼티 하나뿐이다.
저장·카테고리·핀 로직은 지도 종류와 무관하게 그대로 쓴다.

### 장소 검색 — ⚠️ 서버가 하나 필요하다

네이버 **지역검색 API**(`openapi.naver.com/v1/search/local.json`)는
요청 헤더에 `X-Naver-Client-Id` 와 **`X-Naver-Client-Secret`** 을 같이 보내야 한다.

앱에 Secret을 넣으면 바이너리에서 그대로 털린다. 앱에서 직접 부르면 안 된다.

권하는 구성:

```
앱  →  Firebase Cloud Functions (Secret 보관)  →  네이버 지역검색 API
```

Functions를 쓰려면 Firebase 요금제를 **Blaze(종량제)** 로 올려야 한다.
무료 할당량 안에서는 사실상 돈이 들지 않지만 카드 등록은 필요하다.

프록시 주소가 정해지면 [NaverPlaceSearchService](OurLog/Services/PlaceSearchService.swift) 의
`search(query:near:)` 를 채우고 `AppEnvironment.useNaverMaps` 를 `true` 로 바꾸면 된다.

> 지역검색 API는 좌표를 KATECH 계열로 주던 시기가 있었다. 위경도로 바로 쓸 수 있는지
> 응답을 한 번 찍어보고, 아니면 변환을 넣어야 한다.

---

## 아직 안 만든 것

- **위젯** — WidgetKit 익스텐션 타겟을 따로 추가해야 한다.
  본체와 데이터를 나누려면 **App Group** 을 켜고, 디데이·기념일 같은 작은 값만
  공유 `UserDefaults` 에 복사해 두는 방식이 간단하다.
- **상대방 활동 푸시** — FirebaseMessaging + Cloud Functions 트리거
- 기념일 알림은 지금 **기기 로컬 알림**이라 각자 기기에서 따로 예약된다.
