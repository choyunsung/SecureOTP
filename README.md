# Secure OTP - Multi-Platform Authenticator

<div align="center">

🛡️ **Secure OTP** - A modern, secure OTP (One-Time Password) authenticator app for Apple platforms

[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20watchOS-blue.svg)]()
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)]()

</div>

## 📱 Features

### Authentication Methods
- 🍎 **Apple Sign In** - Seamless authentication with Apple ID
- 🔵 **Google Sign In** - Login with your Google account (Coming Soon)
- ✉️ **Email Sign Up** - Create manual accounts with email

### OTP Management
- 🔐 **Secure OTP Storage** - All secrets stored in iCloud Keychain with end-to-end encryption
- ⏱️ **Time-based OTP** - Standard TOTP implementation (30-second intervals)
- 🔄 **iCloud Sync** - Automatic synchronization across all your Apple devices
- 📱 **Multi-Platform** - Native apps for iOS, macOS, and watchOS

## 🎨 Architecture

### Two Main Sections

1. **Authenticator** (User Account)
   - User's own account management
   - Profile information
   - Sign in/out functionality

2. **OTP Services** (External Services)
   - Register external services (Google, GitHub, etc.)
   - Generate OTP codes
   - Manage multiple 2FA accounts

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Frontend (SwiftUI)                                         │
│  ├── iOS: MainTabView (Tab Navigation)                      │
│  ├── macOS: MainSidebarView (Sidebar Layout)                │
│  └── watchOS: WatchContentView (Read-only)                  │
└────────────────────────┬────────────────────────────────────┘
                         │ REST API (JWT Auth)
┌────────────────────────▼────────────────────────────────────┐
│  Backend (Express.js + SQLite)                              │
│  ├── /api/auth - Authentication (Apple/Google/Email)        │
│  └── /api/otp  - OTP CRUD + Sync                            │
└─────────────────────────────────────────────────────────────┘
```

**Sync Flow:**
```
UserDefaults (Local) → Server Fetch → Merge (dedupe by secret+accountName) → Local Save → Server Sync
```

## 🏗️ Technical Stack

- **SwiftUI** - Modern declarative UI framework
- **AuthenticationServices** - Apple Sign In integration
- **Security Framework** - Keychain and cryptographic operations
- **Combine** - Reactive state management
- **iCloud Keychain** - Secure, synchronized storage

## 📂 Project Structure

```
SecureOTP/
├── backend/                          # Node.js/Express Backend API
│   ├── src/
│   │   ├── index.js                  # Express app entry point
│   │   ├── db.js                     # SQLite database (better-sqlite3)
│   │   ├── middleware/
│   │   │   └── auth.js               # JWT authentication middleware
│   │   └── routes/
│   │       ├── auth.js               # Auth API (Apple/Google/Email)
│   │       └── otp.js                # OTP CRUD & sync API
│   ├── data/                         # SQLite database files
│   ├── package.json
│   └── Dockerfile                    # Container deployment
│
├── SecureOTP/                        # Swift Frontend (Multi-platform)
│   ├── Shared/                       # Shared code (iOS, macOS, watchOS)
│   │   ├── SecureOTPApp.swift        # App entry point
│   │   ├── ContentView.swift         # Root view
│   │   │
│   │   ├── # Authentication
│   │   ├── AuthManager.swift         # Global auth state singleton
│   │   ├── APIService.swift          # HTTP client for backend API
│   │   ├── SignInView.swift          # Sign-in options view
│   │   ├── AccountView.swift         # Account management view
│   │   │
│   │   ├── # OTP Core
│   │   ├── OTPAccount.swift          # OTP model, otpauth:// parsing
│   │   ├── TOTP.swift                # RFC 6238 TOTP algorithm
│   │   ├── Base32.swift              # Base32 encoding/decoding
│   │   ├── OTPListView.swift         # Main OTP list with sync
│   │   ├── OTPRowView.swift          # Single OTP display row
│   │   ├── AddOTPView.swift          # Add new OTP view
│   │   │
│   │   ├── # Features
│   │   ├── SubscriptionManager.swift # In-app purchase management
│   │   ├── SubscriptionView.swift    # Subscription UI
│   │   ├── BiometricAuthManager.swift# Face ID/Touch ID
│   │   ├── BiometricSettingsView.swift
│   │   ├── BiometricLockView.swift
│   │   ├── DeviceManager.swift       # Device sync management
│   │   ├── DeviceListView.swift
│   │   ├── WatchConnectivityManager.swift
│   │   ├── AdBannerView.swift        # Ad integration
│   │   │
│   │   ├── # Utilities
│   │   ├── LocalizationManager.swift # i18n support
│   │   ├── SharedUserDefaults.swift  # App Group storage
│   │   └── SplashView.swift
│   │
│   ├── iOS/                          # iOS-specific
│   │   ├── MainTabView.swift         # Tab navigation (OTP | Account)
│   │   └── QRScannerView.swift       # Camera QR scanner (Vision)
│   │
│   ├── macOS/                        # macOS-specific
│   │   ├── MainSidebarView.swift     # Sidebar navigation
│   │   ├── ScreenQRScannerView.swift # Screen capture QR scanner
│   │   └── CatalystScreenQRScannerView.swift
│   │
│   ├── watchOS/                      # watchOS-specific
│   │   ├── WatchApp.swift            # Watch app entry
│   │   ├── WatchContentView.swift    # Read-only OTP list
│   │   └── WatchOTPManager.swift     # Watch state management
│   │
│   └── Assets.xcassets/              # App icons & assets
│
├── SecureOTP.xcodeproj/              # Xcode project
│
├── docs/                             # Documentation
│   ├── FUNCTIONAL_SPEC.md            # Functional specification
│   └── TEST_REPORT.md                # Test reports
│
├── fastlane/                         # Automated deployment
├── screenshots/                      # App Store screenshots
├── SecureSignInClientTests/          # Unit tests
├── SecureSignInClientUITests/        # UI tests
│
├── README.md                         # This file
├── CLAUDE.md                         # Claude Code instructions
└── DEPLOYMENT.md                     # Deployment guide
```

### Backend API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/auth/signup` | POST | Email signup |
| `/api/auth/signin` | POST | Email signin |
| `/api/auth/apple` | POST | Apple OAuth |
| `/api/auth/google` | POST | Google OAuth |
| `/api/auth/me` | GET | Get current user (JWT) |
| `/api/otp` | GET | List OTP accounts (JWT) |
| `/api/otp` | POST | Add OTP account (JWT) |
| `/api/otp/sync` | POST | Bulk sync OTP accounts (JWT) |
| `/api/otp/:id` | PUT | Update OTP account (JWT) |
| `/api/otp/:id` | DELETE | Delete OTP account (JWT) |
| `/api/otp/parse-uri` | POST | Parse otpauth:// URI (JWT) |

## 🔐 Security Features

### Keychain Storage
- ✅ End-to-end encryption via iCloud Keychain
- ✅ `kSecAttrSynchronizable` enabled for cross-device sync
- ✅ `kSecAttrAccessibleAfterFirstUnlock` for security
- ✅ No server-side storage - all data stays on your devices

### Data Protection
- ✅ Secrets never leave Apple's encrypted ecosystem
- ✅ App sandbox isolation
- ✅ Automatic device-to-device encryption

## 🚀 Getting Started

### Requirements
- Xcode 15.0+
- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+
- Swift 5.9+
- Apple Developer Account (for Sign in with Apple)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/SecureSignInClient.git
cd SecureSignInClient
```

2. Open the project in Xcode:
```bash
open SecureSignInClient.xcodeproj
```

3. Configure signing:
   - Select your development team
   - Update bundle identifier: `com.quettasoft.secureotp`

4. Build and run!

## 📱 Platform-Specific Features

### iOS
- ✅ TabView navigation (Account / OTP Services)
- ✅ Card-style OTP display
- ✅ Full authentication capabilities
- ✅ Beautiful gradients and shadows

### macOS
- ✅ Sidebar navigation
- ✅ Native macOS design patterns
- ✅ Full functionality

### watchOS
- ✅ Read-only OTP viewer
- ✅ Sync from iPhone/Mac
- ✅ Quick OTP access on your wrist

## 🎯 Roadmap

### v1.0 (Current)
- [x] Apple Sign In integration
- [x] Manual email sign up
- [x] OTP code generation
- [x] iCloud Keychain sync
- [x] Multi-platform support

### v1.1 (Planned)
- [ ] Google Sign In SDK integration
- [ ] Face ID/Touch ID app lock
- [ ] QR code scanning for easy setup
- [ ] Export/Import accounts

### v1.2 (Future)
- [ ] Biometric verification for OTP access
- [ ] Account usage statistics
- [ ] Multiple user profiles
- [ ] Backup/restore functionality

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- TOTP algorithm based on RFC 6238
- SwiftOTP implementation for cryptographic operations
- Apple's AuthenticationServices framework

## 📧 Contact

For questions or suggestions, please open an issue on GitHub.

---

<div align="center">

**Built with ❤️ using SwiftUI**

🛡️ Secure your digital life, one code at a time

</div>
