<div align="center">

<img src="OurLog/Assets.xcassets/AppIcon.appiconset/OurLogAppIcon.png" width="120" alt="OurLog 앱 아이콘" />

# OurLog

**둘이 함께 쓰는 커플 기록장** 🐾

만난 날, 기념일, 데이트 장소, 일정, 일기를 한곳에 모으고<br/>
함께 키우는 도트 고양이가 둘의 기록을 먹고 자라요.

![iOS](https://img.shields.io/badge/iOS-18.2+-000000?style=flat-square&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0D96F6?style=flat-square&logo=swift&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-DD2C00?style=flat-square&logo=firebase&logoColor=white)
![NAVER Maps](https://img.shields.io/badge/NAVER_Maps-03C75A?style=flat-square&logo=naver&logoColor=white)
![Kakao](https://img.shields.io/badge/Kakao_Local-FFCD00?style=flat-square&logo=kakao&logoColor=000000)

</div>

<br/>

> 종이 위에 펜으로 그린 듯한 **손그림 UI**와 **손글씨**로 꾸몄고,<br/>
> 모든 기록은 두 사람에게 **실시간으로 공유**됩니다.

<!-- 스크린샷을 추가하려면 screenshots/ 폴더에 이미지를 넣고 아래 주석을 풀어 주세요.
<div align="center">
  <img src="screenshots/home.png" width="19%" />
  <img src="screenshots/map.png" width="19%" />
  <img src="screenshots/calendar.png" width="19%" />
  <img src="screenshots/diary.png" width="19%" />
  <img src="screenshots/cat.png" width="19%" />
</div>
-->

<br/>

## ✨ 이런 걸 할 수 있어요

<table>
  <tr>
    <td width="50%" valign="top">

### 🏠 우리집
- 만난 지 **며칠째**인지 한눈에
- 다가오는 기념일 (100일 단위 · 생일 · 직접 추가)
- 오늘 일정 · 최근 일기 · 고양이 근황

    </td>
    <td width="50%" valign="top">

### 🗺️ 우리 지도
- 저장한 장소를 **카테고리별 핀**으로
- 카카오 검색 + **현 지도에서 검색**
- 아래서 올라오는 결과 판, 최근 검색 기록
- 사진 · 블로그 후기 · 내 위치에서 거리

    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">

### 📅 우리 달력
- 둘이 같이 쓰는 일정 (누가 썼는지 색으로)
- 일정에 **장소 연결** → 바로 상세 보기
- 스와이프로 달 이동 · 연월 점프 · 오늘로

    </td>
    <td width="50%" valign="top">

### 📖 데이트 일기
- 사진 여러 장과 함께 남기는 하루
- 그날의 기분, 다녀온 장소 연결

    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">

### 🐱 함께 키우는 고양이
- 알에서 시작해 **6단계**로 자라는 회색 도트 고양이
- 출석 · 일기 · 일정 · 장소 기록으로 애정도 UP
- 하루 한도가 있어 **약 1년**에 걸쳐 천천히 성장
- 모자 · 안경 · 목걸이 꾸미기, 방 꾸미기

    </td>
    <td width="50%" valign="top">

### 🎀 그 밖에
- 기념일 · 디데이 **알림**
- 홈 화면 · 잠금 화면 **위젯**
- 색 **테마** (종이 색까지 함께 바뀜)
- **초대 코드**로 상대방과 연결

    </td>
  </tr>
</table>

<br/>

## 🛠 기술 스택

| | |
| :-- | :-- |
| **UI** | SwiftUI · Observation(`@Observable`) · WidgetKit |
| **로그인** | Firebase Auth + Google 로그인 |
| **데이터** | Cloud Firestore — 실시간 리스너로 두 사람 동기화 |
| **지도** | NAVER Maps iOS SDK |
| **장소 검색** | 카카오 로컬 키워드 검색 |
| **사진 · 후기** | 네이버 검색 API (이미지 · 블로그) |
| **패키지** | Swift Package Manager |

> 💡 지도 키가 없으면 **Apple 지도**로, Firebase 설정이 없으면 **기기 안에만 저장하는 로컬 모드**로 동작해요.

<br/>

## 📁 폴더 구조

```
OurLog/
├── App/             앱 상태 · 루트 화면 · 탭 · 위젯 데이터 내보내기
├── DesignSystem/    손그림 카드 · 버튼 · 입력칸, 이미지 로더
├── Features/
│   ├── Home/        우리집
│   ├── Map/         지도 · 검색 · 장소 상세 · 카테고리 · 최근 기록
│   ├── Calendar/    공유 달력 · 일정
│   ├── Diary/       데이트 일기
│   ├── Cat/         고양이 방 · 꾸미기 · 진화
│   ├── Onboarding/  로그인 · 커플 연결
│   └── Settings/    설정 · 기념일 · 테마
├── Models/          데이터 모델
└── Services/        Firestore · 로그인 · 장소 검색 · 알림 · 사진
Shared/              앱 + 위젯 공용 (테마, 손그림 도형, 도트 스프라이트, 글꼴)
OurLogWidget/        위젯 익스텐션
```

<br/>

## 🚀 직접 빌드하기

API 키와 Firebase 설정 파일은 저장소에 올리지 않았어요. 아래 파일들을 직접 만들어 넣으면 모든 기능이 동작합니다.

<details>
<summary><b>1. Firebase 설정</b></summary>

<br/>

1. Firebase 콘솔에서 프로젝트를 만들고 iOS 앱을 추가합니다 (번들 ID는 내 값으로).
2. **Authentication** → Google 로그인 사용 설정
3. **Firestore Database** 생성
4. 받은 `GoogleService-Info.plist`를 `OurLog/` 폴더에 넣기
5. 그 안의 `REVERSED_CLIENT_ID` 값을 `OurLog-Info.plist`의 URL 스킴(`CFBundleURLSchemes`)에 넣기

보안 규칙은 커플 문서의 `memberIDs`에 있는 사용자만 그 커플 데이터를 읽고 쓸 수 있게 설정합니다.

```
couples/{coupleID}                      커플 정보 (멤버 · 시작일 · 테마 · 고양이 · memberIDs)
couples/{coupleID}/anniversaries/{id}
couples/{coupleID}/places/{id}
couples/{coupleID}/categories/{id}
couples/{coupleID}/events/{id}
couples/{coupleID}/diaries/{id}
users/{uid}                             내가 속한 커플
invites/{code}                          초대 코드 → 커플
```

</details>

<details>
<summary><b>2. 네이버 키 — <code>OurLog/NaverKeys.plist</code></b></summary>

<br/>

NAVER Cloud Platform에서 **Maps**를 신청하고 iOS 번들 ID를 등록합니다.
장소 사진 · 후기를 보려면 **검색 API**(이미지 · 블로그)도 신청해 주세요.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>MapKeyId</key>
    <string>지도 Client ID</string>
    <key>SearchClientId</key>
    <string>검색 API Client ID</string>
    <key>SearchClientSecret</key>
    <string>검색 API Client Secret</string>
</dict>
</plist>
```

</details>

<details>
<summary><b>3. 카카오 키 — <code>OurLog/KakaoKeys.plist</code></b></summary>

<br/>

Kakao Developers에서 앱을 만들고 **REST API 키**를 받습니다.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>RestApiKey</key>
    <string>REST API 키</string>
</dict>
</plist>
```

</details>

<details>
<summary><b>4. 실행</b></summary>

<br/>

`OurLog.xcodeproj`를 Xcode로 열고 `OurLog` 스킴을 실행하면 패키지는 자동으로 받아져요.
위젯이 앱 데이터를 보려면 두 타깃의 **App Group**을 내 계정에 맞게 바꿔 주세요.

</details>

<br/>

## 📝 참고

- 두 사람만 쓰는 개인 프로젝트라 검색 API 키를 앱에 직접 넣었어요. 여러 사람에게 배포한다면 서버(예: Cloud Functions)를 거쳐 호출하는 편이 안전합니다.
- 장소 사진은 네이버 이미지 검색 결과라 다른 곳 사진이 섞일 수 있어요.
- 글꼴: 나눔손글씨 다시 시작해 (네이버 나눔글꼴 · SIL OFL)

<div align="center">
<br/>

made with 🩶 for us two

</div>
