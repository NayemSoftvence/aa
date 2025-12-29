# 📱 LiveKit Calling App - Complete Documentation

A production-ready peer-to-peer video calling application built with Flutter, Firebase, and LiveKit.

## 📚 Documentation Overview

This project includes comprehensive documentation for developers:

### Quick Access
| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[QUICK_START.md](./QUICK_START.md)** | Get running in 5 minutes | 5 min |
| **[SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md)** | Architecture & design decisions | 20 min |
| **[IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)** | Detailed development guide | 30 min |
| **[API_REFERENCE.md](./API_REFERENCE.md)** | Complete API documentation | 15 min |
| **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** | Common issues & solutions | 20 min |

---

## 🚀 Quick Start

New to the project? Start here:

```bash
# 1. Clone repository
git clone <repository-url>
cd calling\ app

# 2. Setup Flutter app
cd livekit_calling_app
flutter pub get
flutter pub run build_runner build

# 3. Setup backend
cd ../livekit
npm install

# 4. Configure Firebase (get credentials from Firebase Console)
# Create .env file with Firebase & LiveKit credentials

# 5. Start development
# Terminal 1: netlify dev (from livekit/)
# Terminal 2: flutter run (from livekit_calling_app/)
```

For detailed setup, see [QUICK_START.md](./QUICK_START.md).

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Mobile App Layer                             │
│  Flutter (iOS/Android) - Video Calling Interface                │
└──────────────────────────┬──────────────────────────────────────┘
                           │ REST API + WebSockets
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Serverless Backend Layer                        │
│  Netlify Functions (Node.js)                                    │
│  - Token Generation  - Notifications  - Call Management         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┬──────────────┐
        ▼                  ▼                  ▼              ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────┐
│  Firebase    │  │  Cloud       │  │  LiveKit     │  │  Push    │
│  Auth        │  │  Firestore   │  │  Server      │  │  Notif   │
│              │  │              │  │              │  │          │
│ - OAuth      │  │ - Users      │  │ - Signaling  │  │ - FCM    │
│ - Users      │  │ - Calls      │  │ - Media      │  │ - APNS   │
└──────────────┘  └──────────────┘  └──────────────┘  └──────────┘
```

See [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) for detailed architecture.

---

## 📋 Key Features

### User Authentication
- ✅ Google Sign-In
- ✅ Apple Sign-In (iOS)
- ✅ Firebase Authentication
- ✅ Automatic token refresh

### Calling
- ✅ Peer-to-peer video calls
- ✅ Audio & video streams
- ✅ Call accept/decline/end
- ✅ Real-time user presence

### Notifications
- ✅ Incoming call notifications
- ✅ Call state notifications (accepted/declined/ended)
- ✅ Multi-device support
- ✅ iOS APNs & Android GCM

### User Interface
- ✅ Modern Material Design
- ✅ Responsive layout
- ✅ Dark/Light theme support
- ✅ Smooth animations

### Developer Experience
- ✅ Hot reload support
- ✅ Comprehensive error handling
- ✅ Debug logging
- ✅ Local Firebase emulator support

---

## 📁 Project Structure

```
calling app/
├── livekit_calling_app/              # Flutter Mobile App
│   ├── lib/
│   │   ├── main.dart                 # Entry point
│   │   ├── features/                 # Feature modules
│   │   │   ├── auth/                 # Authentication
│   │   │   ├── call/                 # Call screen
│   │   │   └── home/                 # Home/user list
│   │   ├── helpers/                  # Utilities
│   │   │   ├── notification_service.dart
│   │   │   ├── social_auth.dart
│   │   │   └── di.dart
│   │   ├── providers/                # State management
│   │   ├── networks/                 # API client
│   │   └── constants/                # App constants
│   ├── android/                      # Android native code
│   ├── ios/                          # iOS native code
│   ├── pubspec.yaml                  # Dependencies
│   └── firebase.json                 # Firebase config
│
├── livekit/                          # Backend
│   ├── netlify/
│   │   └── functions/
│   │       ├── token.js              # Generate access tokens
│   │       ├── notify.js             # Send notifications
│   │       ├── callAccepted.js       # Accept notification
│   │       ├── callDeclined.js       # Decline notification
│   │       └── endCall.js            # End call
│   ├── package.json                  # Node dependencies
│   └── netlify.toml                  # Netlify config
│
├── SYSTEM_DESIGN.md                  # Architecture documentation
├── IMPLEMENTATION_GUIDE.md           # Development guide
├── API_REFERENCE.md                  # API documentation
├── QUICK_START.md                    # Quick setup guide
└── TROUBLESHOOTING.md                # Common issues
```

---

## 🔧 Technology Stack

### Frontend
- **Flutter**: Cross-platform mobile framework
- **Dart**: Programming language
- **Provider**: State management
- **Dio**: HTTP client
- **LiveKit Client**: WebRTC library

### Backend
- **Node.js**: Runtime
- **Netlify Functions**: Serverless compute
- **Firebase Admin SDK**: Backend services
- **LiveKit Server SDK**: Token generation

### Infrastructure
- **Firebase**: Auth, Firestore, Messaging
- **LiveKit**: Real-time communication
- **Netlify**: Serverless deployment

See [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) for complete tech stack.

---

## 📖 Detailed Documentation

### 1. System Design ([SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md))
- Complete architecture overview
- Data flow diagrams
- Database schema
- API specifications
- Authentication flows
- Real-time communication details
- Deployment architecture

**Who should read**: Architects, Tech Leads, Backend Developers

### 2. Implementation Guide ([IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md))
- Project setup instructions
- Flutter app structure
- Backend function specifications
- Firebase configuration
- Development workflow
- Building & deployment
- Testing guide
- Code examples

**Who should read**: Full-stack Developers, Mobile Developers, Backend Developers

### 3. API Reference ([API_REFERENCE.md](./API_REFERENCE.md))
- All API endpoints documented
- Request/response formats
- Error handling
- CORS configuration
- Integration examples
- Rate limiting
- Testing guide

**Who should read**: Mobile Developers, Backend Developers, QA Engineers

### 4. Quick Start ([QUICK_START.md](./QUICK_START.md))
- 5-minute setup guide
- Common issues & fixes
- Key feature testing
- Configuration files
- Important directories

**Who should read**: New Developers, Onboarding, Quick Setup

### 5. Troubleshooting ([TROUBLESHOOTING.md](./TROUBLESHOOTING.md))
- Common setup issues & solutions
- Firebase configuration issues
- Authentication troubleshooting
- Notification issues
- Live call debugging
- FAQ section
- Performance tips

**Who should read**: Developers debugging issues, QA Engineers, DevOps

---

## 🚀 Deployment

### Mobile App Deployment

#### iOS
```bash
flutter build ipa --release
# Submit to App Store
```

#### Android
```bash
flutter build appbundle
# Submit to Google Play Store
```

### Backend Deployment

```bash
cd livekit
netlify deploy --prod
# Functions deployed to production
```

See [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md) for detailed deployment steps.

---

## 📝 Development Workflow

### Local Development

```bash
# Start Netlify functions
cd livekit
netlify dev

# In another terminal, run Flutter app
cd ../livekit_calling_app
flutter run
```

### Testing Changes

```bash
# Unit tests
flutter test

# Integration tests
flutter drive --target=test_driver/app.dart

# Manual testing checklist in TROUBLESHOOTING.md
```

### Code Quality

```bash
# Format code
dart format lib/

# Analyze code
dart analyze

# Check for lints
flutter analyze
```

---

## 🔐 Security Considerations

### Authentication
- Firebase ID tokens for API auth
- Bearer token in Authorization header
- Server-side token verification
- Automatic token refresh

### Data Protection
- HTTPS/WSS for all communications
- Firestore security rules
- User data isolation
- Private keys in environment variables

### API Security
- CORS properly configured
- Rate limiting recommended
- Payload validation
- Input sanitization

See [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) for security details.

---

## 📊 Project Statistics

- **Flutter Code**: ~2000+ lines
- **Node.js Backend**: ~500+ lines
- **Configuration Files**: Firebase, Netlify, Gradle, CocoaPods
- **Supported Platforms**: iOS 11+, Android 21+
- **Documentation**: 5 comprehensive guides

---

## 🤝 Contributing

### Code Style
- Follow Dart style guide
- Use meaningful variable names
- Add comments for complex logic
- Write tests for new features

### Commit Message Format
```
<type>: <subject>

<body>

<footer>
```

Types: feat, fix, docs, style, refactor, test, chore

### Pull Request Process
1. Create feature branch
2. Make changes and test
3. Update documentation
4. Create pull request
5. Code review
6. Merge to main

---

## 📞 Support & Resources

### Documentation Links
- [System Design](./SYSTEM_DESIGN.md) - Architecture
- [Implementation Guide](./IMPLEMENTATION_GUIDE.md) - Development
- [API Reference](./API_REFERENCE.md) - API specs
- [Quick Start](./QUICK_START.md) - Setup guide
- [Troubleshooting](./TROUBLESHOOTING.md) - Issues & FAQ

### External Resources
- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [LiveKit Documentation](https://docs.livekit.io)
- [Dart Guide](https://dart.dev/guides)

### Getting Help
1. Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues
2. Review relevant documentation
3. Check Firebase Console for errors
4. View logs: `flutter logs` or `firebase functions:log`
5. Search existing issues/Stack Overflow
6. Contact Firebase/LiveKit support if needed

---

## 📈 Performance Monitoring

### Key Metrics
- Call success rate
- Average call duration
- Token generation latency
- FCM delivery rate
- App crash rate

### Monitoring Tools
- Firebase Analytics
- Firebase Crashlytics
- Firebase Performance
- LiveKit Insights Dashboard

---

## 🎯 Roadmap

### Current Version (v1.0)
- [x] Peer-to-peer calling
- [x] Google & Apple SignIn
- [x] Push notifications
- [x] Call history

### Future Features
- [ ] Group calling
- [ ] Call recording
- [ ] Video filters
- [ ] Screen sharing
- [ ] Message history
- [ ] Contact management
- [ ] Missed call callbacks
- [ ] Call scheduling

---

## 📄 License

[Your License Here]

---

## 👥 Team

**Developed by**: Softvence Technologies

**Project**: LiveKit Calling App

**Version**: 1.0.0

**Last Updated**: December 2025

---

## 📝 Document Index

```
Documentation/
├── README.md (this file)                    # Overview & navigation
├── QUICK_START.md                           # 5-minute setup
├── SYSTEM_DESIGN.md                         # Architecture
├── IMPLEMENTATION_GUIDE.md                  # Detailed development
├── API_REFERENCE.md                         # API documentation
└── TROUBLESHOOTING.md                       # Issues & FAQ
```

---

## ⚡ Quick Links

| Need | Go To |
|------|-------|
| Setup & Running | [QUICK_START.md](./QUICK_START.md) |
| Understand Architecture | [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) |
| Code & Develop | [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md) |
| Use API | [API_REFERENCE.md](./API_REFERENCE.md) |
| Fix Issues | [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) |

---

## 💡 Pro Tips

1. **Always read QUICK_START.md first** - Gets you running quickly
2. **Check TROUBLESHOOTING.md before asking** - 90% of issues covered
3. **Refer to SYSTEM_DESIGN.md** - When you need to understand why something works
4. **Use API_REFERENCE.md** - When integrating with backend
5. **IMPLEMENTATION_GUIDE.md** - For detailed development reference

---

## 🎉 You're All Set!

You have everything needed to:
- ✅ Understand the system architecture
- ✅ Setup development environment
- ✅ Build and deploy the application
- ✅ Debug and troubleshoot issues
- ✅ Contribute to the project

**Start with [QUICK_START.md](./QUICK_START.md) to get your environment running! 🚀**

---

**Questions?** Check the relevant documentation file above or see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for FAQs.

