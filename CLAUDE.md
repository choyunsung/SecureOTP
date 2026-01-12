# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

SecureOTP는 iOS, macOS, watchOS용 멀티플랫폼 TOTP 인증 앱입니다. SwiftUI 프론트엔드와 Node.js/Express 백엔드 API로 구성됩니다.

## 개발 명령어

### 백엔드 (Node.js)
```bash
cd backend
npm install          # 의존성 설치
npm run dev          # 개발 서버 (nodemon, 자동 재시작)
npm start            # 프로덕션 서버
```

### 프론트엔드 (Swift/Xcode)
```bash
open SecureOTP.xcodeproj   # Xcode에서 프로젝트 열기
```
- Xcode에서 빌드: `Cmd+B`
- Xcode에서 실행: `Cmd+R`
- 테스트 실행: `Cmd+U`
- 스킴 선택으로 플랫폼 전환 (iOS, macOS, watchOS)

### 백엔드 API 상태 확인
```bash
# 로컬 개발
curl http://localhost:3000/health

# 프로덕션
curl https://secureotp.quetta-soft.com/health
```

### 프로덕션 배포 (서버: subdeal@51.161.197.177)
```bash
cd /data/SecureOTP && git pull origin main
cd backend && podman build -t secureotp-backend:latest .
podman stop secureotp-backend && podman rm secureotp-backend
podman run -d --name secureotp-backend --restart always \
  -p 3101:3000 -v /data/SecureOTP/backend/data:/app/data:Z \
  -e JWT_SECRET='...' secureotp-backend:latest
```

## 아키텍처

### 2계층 시스템
```
┌─────────────────────────────────────────────────────┐
│  프론트엔드 (SwiftUI)                                │
│  ├── iOS: MainTabView (탭 네비게이션)               │
│  ├── macOS: MainSidebarView (사이드바)              │
│  └── watchOS: WatchContentView (읽기 전용)          │
└────────────────────┬────────────────────────────────┘
                     │ REST API
┌────────────────────▼────────────────────────────────┐
│  백엔드 (Express.js)                                 │
│  ├── /api/auth - 인증 (Apple/Google/Email)          │
│  └── /api/otp  - OTP 계정 CRUD + 동기화              │
└─────────────────────────────────────────────────────┘
```

### 핵심 Swift 파일 역할
| 파일 | 역할 |
|------|------|
| `AuthManager.swift` | 전역 인증 상태 싱글톤, 로그인/로그아웃 처리 |
| `APIService.swift` | HTTP 클라이언트, 모든 백엔드 API 호출 |
| `OTPListView.swift` | 메인 OTP 목록, 로컬-서버 동기화 로직 |
| `SecureOTPApp.swift` | 앱 진입점, 플랫폼별 윈도우 관리 |
| `TOTP.swift` | RFC 6238 TOTP 알고리즘 구현 |
| `OTPAccount.swift` | OTP 모델, otpauth:// URI 파싱 |

### 백엔드 구조
```
backend/src/
├── index.js           # Express 앱 설정, 라우트 등록
├── db.js              # SQLite 초기화, 스키마 정의
├── middleware/auth.js # JWT 인증 미들웨어
└── routes/
    ├── auth.js        # 회원가입/로그인 (Apple/Google/Email)
    └── otp.js         # OTP CRUD, 동기화, URI 파싱
```

### 데이터 동기화 흐름
```
UserDefaults (로컬) → 서버 fetch → 병합 (secret+accountName 중복제거) → 로컬 저장 → 서버 sync
```

## 플랫폼별 특이사항

### iOS
- `MainTabView.swift`: 탭 네비게이션 (OTP | Account)
- `QRScannerView.swift`: Vision 프레임워크 카메라 QR 스캔

### macOS
- `MainSidebarView.swift`: 단일 뷰 사이드바 레이아웃
- `ScreenQRScannerView.swift`: 화면 캡처 기반 QR 스캔 (카메라 불필요)
- NSWindow/NSWindowDelegate로 윈도우 관리

### watchOS
- 읽기 전용 (추가/편집 불가)
- `WatchOTPManager.swift`로 상태 관리

## API 엔드포인트

### 인증 (/api/auth)
- `POST /signup` - 이메일 가입
- `POST /signin` - 이메일 로그인
- `POST /apple` - Apple OAuth
- `POST /google` - Google OAuth
- `GET /me` - 현재 사용자 조회 (JWT 필요)

### OTP (/api/otp, 모두 JWT 필요)
- `GET /` - OTP 목록 조회
- `POST /` - OTP 추가
- `POST /sync` - 일괄 동기화
- `PUT /:id` - OTP 수정
- `DELETE /:id` - OTP 삭제
- `POST /parse-uri` - otpauth:// URI 파싱

## 주요 의존성

### 프론트엔드
- SwiftUI, Combine (상태 관리)
- AuthenticationServices (Apple Sign In)
- CommonCrypto (HMAC-SHA1/256/512)
- Vision (QR 스캔)

### 백엔드
- express, cors, jsonwebtoken
- bcryptjs (비밀번호 해싱)
- better-sqlite3 (SQLite)
- uuid

## 환경 설정

### 백엔드 (.env)
```
PORT=3000
JWT_SECRET=your-secret-key
```

### 번들 ID
- `com.quettasoft.app.SecureOTP` (메인)
- 최소 요구사항: iOS 17.0+ / macOS 14.0+ / watchOS 10.0+
