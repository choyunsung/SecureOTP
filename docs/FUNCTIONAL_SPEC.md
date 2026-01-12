# SecureOTP 기능 정의서

**버전**: 1.0.0
**최종 수정일**: 2026-01-12
**작성자**: Quetta Soft

---

## 1. 개요

### 1.1 앱 소개
SecureOTP는 TOTP(Time-based One-Time Password) 인증 코드를 관리하는 멀티 플랫폼 앱입니다. iOS, macOS, watchOS를 지원하며, 클라우드 동기화와 생체 인증을 제공합니다.

### 1.2 지원 플랫폼
| 플랫폼 | 최소 버전 | 비고 |
|--------|----------|------|
| iOS | 17.0+ | iPhone, iPad |
| macOS | 14.0+ | Apple Silicon, Intel |
| watchOS | 10.0+ | Apple Watch |

### 1.3 기술 스택
- **Frontend**: SwiftUI, Combine
- **Backend**: Node.js, Express, SQLite
- **인증**: JWT, Apple Sign In, Google Sign In
- **보안**: Face ID/Touch ID, Keychain, AES 암호화

---

## 2. 핵심 기능

### 2.1 OTP 관리

#### 2.1.1 OTP 코드 생성
| 항목 | 설명 |
|------|------|
| **알고리즘** | TOTP (RFC 6238) |
| **해시** | SHA-1, SHA-256, SHA-512 |
| **코드 길이** | 6자리 (기본), 8자리 지원 |
| **갱신 주기** | 30초 (기본), 60초 지원 |
| **시각화** | 실시간 카운트다운 타이머 |

#### 2.1.2 OTP 계정 추가
```
지원 방식:
├── QR 코드 스캔 (카메라)
├── 화면 QR 스캔 (macOS/Mac Catalyst)
└── 수동 입력 (Issuer, Account, Secret)
```

**QR 코드 형식**: `otpauth://totp/{issuer}:{account}?secret={secret}&issuer={issuer}`

#### 2.1.3 OTP 계정 관리
- **목록 표시**: 발급자, 계정명, 현재 OTP 코드
- **복사**: 탭하여 클립보드 복사
- **삭제**: 스와이프 또는 편집 모드
- **정렬**: 발급자 기준 자동 정렬

### 2.2 인증 시스템

#### 2.2.1 소셜 로그인
| 제공자 | 상태 | SDK |
|--------|------|-----|
| Apple | ✅ 구현됨 | AuthenticationServices |
| Google | ✅ 구현됨 | 시뮬레이션 (프로덕션에서 Google SDK 필요) |
| Email | ✅ 구현됨 | 커스텀 구현 |

#### 2.2.2 Apple 로그인 흐름
```
1. SignInWithAppleButton 탭
2. Apple ID 인증 (Face ID/Touch ID)
3. 사용자 정보 수신 (userId, email, name)
4. 백엔드 /auth/apple API 호출
5. JWT 토큰 발급 및 저장
6. 로그인 완료 → MainTabView 이동
```

#### 2.2.3 인증 토큰 관리
- **저장소**: UserDefaults (auth_token)
- **유효기간**: 30일
- **자동 갱신**: 미구현 (향후 추가 예정)

### 2.3 생체 인증 (Face ID / Touch ID)

#### 2.3.1 지원 생체 인증
| 타입 | 아이콘 | 지원 기기 |
|------|--------|----------|
| Face ID | `faceid` | iPhone X 이상, iPad Pro |
| Touch ID | `touchid` | iPhone 8 이하, MacBook |
| Optic ID | `opticid` | Apple Vision Pro |

#### 2.3.2 앱 잠금 흐름
```
앱 실행
    ↓
SplashView (2초)
    ↓
BiometricAuthManager.isBiometricEnabled 확인
    ↓ (활성화됨)
BiometricLockView
    ↓
Face ID/Touch ID 인증
    ↓ (성공)
ContentView (메인 화면)
```

#### 2.3.3 설정 화면
- **경로**: Account → Face ID & Passcode
- **기능**: 활성화/비활성화 토글, 테스트 버튼
- **정보**: 보안 안내, 프라이버시 설명

### 2.4 구독 시스템 (In-App Purchase)

#### 2.4.1 플랜 구조
| 플랜 | 가격 | 기능 |
|------|------|------|
| **Free** | 무료 | 로컬 OTP 저장, 무제한 계정, 기본 보안 |
| **Pro** | ₩2,900/월 | 자동 동기화, 클라우드 백업, 기기 복구, 멀티 디바이스(3~5대), 보안 알림 |

#### 2.4.2 지역별 가격
| 지역 | 가격 |
|------|------|
| 한국 (KR) | ₩2,900 |
| 미국 (US) | $1.99 |
| 일본 (JP) | ¥300 |

#### 2.4.3 구독 기능
```swift
// SubscriptionManager.swift
class SubscriptionManager {
    func purchaseProSubscription() async  // 구매
    func restorePurchases() async          // 복원
    func cancelSubscription()              // 취소
    var isPro: Bool                        // Pro 상태 확인
    var canSync: Bool                      // 동기화 가능 여부
}
```

#### 2.4.4 StoreKit 제품 ID
- `com.quettasoft.secureotp.pro.monthly` (월간 구독)

### 2.5 클라우드 동기화 (Pro 전용)

#### 2.5.1 동기화 대상
- OTP 계정 목록
- 인증 토큰
- 사용자 프로필

#### 2.5.2 동기화 API
| 엔드포인트 | 메서드 | 설명 |
|-----------|--------|------|
| `/api/otp` | GET | OTP 목록 조회 |
| `/api/otp` | POST | OTP 추가 |
| `/api/otp/sync` | POST | 전체 동기화 |
| `/api/otp/:id` | DELETE | OTP 삭제 |

#### 2.5.3 Apple Watch 동기화
```
WatchConnectivity 사용:
├── updateApplicationContext() - 백그라운드 동기화
├── transferUserInfo() - 폴백 전송
└── sendMessage() - 실시간 전송 (isReachable 시)
```

### 2.6 기기 관리

#### 2.6.1 지원 기기 타입
| 타입 | 아이콘 | 설명 |
|------|--------|------|
| iPhone | `iphone` | iOS 기기 |
| iPad | `ipad` | iPadOS 기기 |
| Mac | `laptopcomputer` | macOS 기기 |
| Watch | `applewatch` | watchOS 기기 |

#### 2.6.2 기기 목록 기능
- 현재 기기 자동 등록
- 연결된 기기 목록 표시
- 마지막 동기화 시간 표시
- 기기 제거 (스와이프)

---

## 3. 사용자 인터페이스

### 3.1 화면 구조

#### 3.1.1 iOS 화면 구조
```
SplashView
    ↓
BiometricLockView (선택적)
    ↓
ContentView
    ├── MainTabView
    │   ├── OTPListView (Tab 1: OTP)
    │   └── AccountView (Tab 2: Account)
    └── SignInView (미로그인 시)
```

#### 3.1.2 macOS 화면 구조
```
SplashView
    ↓
BiometricLockView (선택적)
    ↓
ContentView
    └── MainSidebarView
        ├── OTP 목록 (Sidebar)
        └── 상세 뷰 (Content)
```

### 3.2 주요 화면

#### 3.2.1 OTPListView
| 요소 | 설명 |
|------|------|
| 헤더 | "OTP 서비스" 타이틀, + 버튼 |
| 목록 | OTPRowView 리스트 |
| 빈 상태 | "No OTP accounts" 메시지 |
| 광고 배너 | Free 사용자에게 Pro 광고 표시 |

#### 3.2.2 OTPRowView
```
┌─────────────────────────────────────┐
│ [Icon] Issuer           123 456    │
│        account@email.com      ⏱ 15 │
└─────────────────────────────────────┘
```

#### 3.2.3 AccountView
```
섹션 구조:
├── 프로필 섹션 (사용자 정보)
├── 설정 섹션
│   ├── 구독 관리
│   ├── 기기 동기화
│   ├── 언어 설정
│   ├── 테마 설정
│   └── Face ID & Passcode
├── 정보 섹션
│   └── 앱 정보
└── 로그아웃 버튼
```

### 3.3 다국어 지원

#### 3.3.1 지원 언어
| 코드 | 언어 |
|------|------|
| en | English |
| ko | 한국어 |
| ja | 日本語 |
| zh | 中文 |

#### 3.3.2 테마 지원
- System (시스템 설정 따름)
- Light (밝은 테마)
- Dark (어두운 테마)

---

## 4. 백엔드 API

### 4.1 서버 정보
- **URL**: `https://secureotp.quetta-soft.com/api`
- **프로토콜**: HTTPS (TLS 1.3)
- **인증**: JWT Bearer Token

### 4.2 인증 API

#### 4.2.1 회원가입
```http
POST /auth/signup
Content-Type: application/json

{
  "name": "string",
  "email": "string",
  "password": "string"
}

Response:
{
  "user": { "id": "uuid", "email": "string", "name": "string" },
  "token": "jwt_token"
}
```

#### 4.2.2 로그인
```http
POST /auth/signin
Content-Type: application/json

{
  "email": "string",
  "password": "string"
}
```

#### 4.2.3 Apple 로그인
```http
POST /auth/apple
Content-Type: application/json

{
  "userId": "apple_user_id",
  "email": "string",
  "name": "string"
}
```

#### 4.2.4 Google 로그인
```http
POST /auth/google
Content-Type: application/json

{
  "userId": "google_user_id",
  "email": "string",
  "name": "string"
}
```

### 4.3 OTP API

#### 4.3.1 OTP 목록 조회
```http
GET /otp
Authorization: Bearer {token}

Response:
{
  "accounts": [
    {
      "id": "uuid",
      "issuer": "string",
      "account_name": "string",
      "secret": "string",
      "algorithm": "SHA1",
      "digits": 6,
      "period": 30
    }
  ]
}
```

#### 4.3.2 OTP 추가
```http
POST /otp
Authorization: Bearer {token}
Content-Type: application/json

{
  "issuer": "string",
  "accountName": "string",
  "secret": "string"
}
```

#### 4.3.3 OTP URI 파싱
```http
POST /otp/parse-uri
Content-Type: application/json

{
  "uri": "otpauth://totp/..."
}

Response:
{
  "type": "totp",
  "issuer": "string",
  "accountName": "string",
  "secret": "string",
  "algorithm": "SHA1",
  "digits": 6,
  "period": 30
}
```

---

## 5. 보안

### 5.1 데이터 보호
| 데이터 | 저장 위치 | 암호화 |
|--------|----------|--------|
| OTP Secret | UserDefaults / Keychain | AES-256 |
| Auth Token | UserDefaults | Base64 |
| 사용자 정보 | UserDefaults | JSON |

### 5.2 네트워크 보안
- HTTPS 필수 (HTTP 차단)
- Certificate Pinning (향후 추가 예정)
- JWT 토큰 만료 관리

### 5.3 생체 인증 보안
- LocalAuthentication Framework 사용
- 생체 데이터는 Secure Enclave에 저장
- 앱에서 생체 데이터 접근 불가

---

## 6. 에러 처리

### 6.1 API 에러 코드
| 코드 | 설명 | 처리 |
|------|------|------|
| 200-299 | 성공 | 정상 처리 |
| 401 | 인증 실패 | 재로그인 요청 |
| 404 | 리소스 없음 | 사용자 알림 |
| 500+ | 서버 에러 | 재시도 또는 알림 |

### 6.2 생체 인증 에러
| 에러 | 설명 | 처리 |
|------|------|------|
| notAvailable | 기기 미지원 | 설정 비활성화 |
| notEnrolled | 등록 안됨 | 설정 안내 |
| lockout | 잠김 | 패스코드 사용 안내 |
| userCancelled | 사용자 취소 | 무시 |
| authenticationFailed | 인증 실패 | 재시도 안내 |

---

## 7. 테스트

### 7.1 테스트 데이터
```swift
// 기본 테스트 OTP 계정
let testAccounts = [
    OTPAccount(issuer: "Google", accountName: "test@gmail.com", secret: "JBSWY3DPEHPK3PXP"),
    OTPAccount(issuer: "GitHub", accountName: "testuser", secret: "HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ"),
    OTPAccount(issuer: "Microsoft", accountName: "test@outlook.com", secret: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ")
]
```

### 7.2 테스트 시나리오

#### 7.2.1 OTP 기능 테스트
- [ ] OTP 코드 30초마다 갱신 확인
- [ ] QR 코드 스캔으로 계정 추가
- [ ] 수동 입력으로 계정 추가
- [ ] OTP 코드 탭하여 클립보드 복사
- [ ] 계정 스와이프 삭제

#### 7.2.2 인증 테스트
- [ ] Apple 로그인 성공
- [ ] Google 로그인 성공
- [ ] Email 로그인/회원가입
- [ ] 로그아웃

#### 7.2.3 생체 인증 테스트
- [ ] Face ID 활성화/비활성화
- [ ] Face ID 앱 잠금 동작
- [ ] Face ID 실패 시 패스코드 폴백
- [ ] 시뮬레이터에서 Enrolled/Matching Face 테스트

#### 7.2.4 구독 테스트
- [ ] 구독 화면 표시
- [ ] Pro 구독 구매 (시뮬레이션)
- [ ] 구매 복원
- [ ] Pro 기능 잠금 해제 확인

#### 7.2.5 동기화 테스트
- [ ] 클라우드 동기화 (Pro)
- [ ] Apple Watch 동기화
- [ ] 기기 목록 표시

---

## 8. 향후 계획

### 8.1 단기 계획 (v1.1)
- [ ] 실제 StoreKit 2 인앱 결제 구현
- [ ] Google Sign-In SDK 통합
- [ ] 인증 토큰 자동 갱신
- [ ] Keychain 마이그레이션

### 8.2 중기 계획 (v1.2)
- [ ] iCloud Keychain 동기화
- [ ] 위젯 지원 (iOS, macOS)
- [ ] Siri Shortcuts
- [ ] Certificate Pinning

### 8.3 장기 계획 (v2.0)
- [ ] FIDO2/WebAuthn 지원
- [ ] 하드웨어 보안 키 지원
- [ ] 엔터프라이즈 관리 기능
- [ ] MDM 통합

---

## 9. 부록

### 9.1 파일 구조
```
SecureOTP/
├── Shared/                    # 공유 코드
│   ├── Models/
│   │   ├── OTPAccount.swift   # OTP 계정 모델
│   │   └── TOTP.swift         # TOTP 알고리즘
│   ├── Views/
│   │   ├── OTPListView.swift  # OTP 목록
│   │   ├── AccountView.swift  # 계정 설정
│   │   └── ...
│   ├── Managers/
│   │   ├── AuthManager.swift          # 인증 관리
│   │   ├── BiometricAuthManager.swift # 생체 인증
│   │   ├── SubscriptionManager.swift  # 구독 관리
│   │   └── DeviceManager.swift        # 기기 관리
│   └── Services/
│       └── APIService.swift   # 백엔드 API
├── iOS/                       # iOS 전용 코드
├── macOS/                     # macOS 전용 코드
└── watchOS/                   # watchOS 전용 코드
```

### 9.2 의존성
| 라이브러리 | 버전 | 용도 |
|-----------|------|------|
| SwiftUI | Native | UI |
| Combine | Native | 상태 관리 |
| LocalAuthentication | Native | 생체 인증 |
| StoreKit | Native | 인앱 결제 |
| WatchConnectivity | Native | Watch 동기화 |
| AuthenticationServices | Native | Apple 로그인 |

### 9.3 환경 변수
```bash
# 백엔드 API
API_BASE_URL=https://secureotp.quetta-soft.com/api

# App Store Connect
APP_STORE_CONNECT_KEY_ID=4CTKM9K7MB
APP_STORE_CONNECT_ISSUER_ID=e719cb18-5d6d-40a9-b6ed-07e4a1fb248d
```

---

**문서 끝**
