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
User Account (Authenticator)
    ↓
AuthenticationManager
    ↓
KeychainHelper (iCloud Keychain)
    ↓
Sync across devices
```

```
OTP Services
    ↓
OTPAccount Models
    ↓
KeychainHelper (iCloud Keychain)
    ↓
Sync across devices
```

## 🏗️ Technical Stack

- **SwiftUI** - Modern declarative UI framework
- **AuthenticationServices** - Apple Sign In integration
- **Security Framework** - Keychain and cryptographic operations
- **Combine** - Reactive state management
- **iCloud Keychain** - Secure, synchronized storage

## 📂 Project Structure

```
SecureSignInClient/
├── AuthenticationManager.swift    # Authentication logic
├── AuthenticatorView.swift        # User profile/sign-in screen
├── SignInView.swift               # Sign-in options (Apple/Google/Email)
├── OTPServicesView.swift          # OTP services list
├── OTPAccountRowView.swift        # OTP display component
├── UserAccount.swift              # User account model
├── OTPAccount.swift               # OTP account model
├── KeychainHelper.swift           # Keychain operations
├── ContentView.swift              # Root navigation
└── SwiftOTP/                      # TOTP generation
    ├── SwiftOTP.swift
    ├── Base32.swift
    └── Data+Bytes.swift
```

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
