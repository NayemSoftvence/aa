# LiveKit Calling App - Developer Onboarding Guide

Welcome to the LiveKit Calling App project! This guide will help you get up to speed quickly.

## 📚 Reading Order

Complete these in sequence to understand the project:

1. **README.md** (5 min) - Overview and documentation index
2. **QUICK_START.md** (5 min) - Get the app running
3. **SYSTEM_DESIGN.md** (20 min) - Understand the architecture
4. **IMPLEMENTATION_GUIDE.md** (30 min) - Deep dive into code
5. **This guide** (10 min) - Tips and best practices

---

## 🎯 Your First Week

### Day 1: Setup & Running
- [ ] Clone repository
- [ ] Complete [QUICK_START.md](./QUICK_START.md)
- [ ] Get app running locally
- [ ] Test with another device/simulator
- [ ] Verify all features work

### Day 2: Understanding Architecture
- [ ] Read [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md)
- [ ] Draw architecture diagram
- [ ] Understand data flows
- [ ] Review database schema
- [ ] Study authentication flow

### Day 3: Code Exploration
- [ ] Read [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)
- [ ] Explore `lib/features/` directory
- [ ] Review key files:
  - `main.dart` - Entry point
  - `lib/features/auth/login.dart` - Authentication
  - `lib/features/home/presentation/home.dart` - Main screen
  - `lib/helpers/notification_service.dart` - Notifications
  - `livekit/netlify/functions/token.js` - Backend

### Day 4: API Integration
- [ ] Read [API_REFERENCE.md](./API_REFERENCE.md)
- [ ] Review each backend function
- [ ] Understand request/response formats
- [ ] Test API endpoints locally
- [ ] Review error handling

### Day 5: Testing & Debugging
- [ ] Set up your debug environment
- [ ] Write a simple test
- [ ] Debug the app with breakpoints
- [ ] Use [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) to understand common issues
- [ ] Participate in code review

---

## 🔧 Essential Setup

### Install Required Tools

```bash
# Check Flutter installation
flutter doctor

# Should show:
# Flutter | Dart SDK | Android toolchain | Xcode (for iOS)
```

### Get Credentials

You need:
1. **Firebase Service Account Key** - From Firebase Console
2. **Google OAuth Credentials** - From Google Cloud Console
3. **iOS Bundle ID** - From Apple Developer Account
4. **Android SHA-1 Fingerprint** - Generated locally

See [QUICK_START.md](./QUICK_START.md) for details.

### Project Directories

Learn these key directories:

```
livekit_calling_app/
├── lib/
│   ├── main.dart                          # Start here
│   ├── features/auth/login.dart           # Auth flow
│   ├── features/home/presentation/home.dart # Main UI
│   ├── features/call/                     # Call screen
│   ├── helpers/
│   │   ├── di.dart                        # Dependency injection
│   │   ├── notification_service.dart      # Push notifications
│   │   └── social_auth.dart               # OAuth helpers
│   ├── providers/call_state_provider.dart # State management
│   ├── networks/dio/
│   │   ├── dio.dart                       # HTTP client
│   │   └── endpoints.dart                 # API endpoints
│   └── constants/app_constants.dart       # Constants

livekit/
└── netlify/functions/
    ├── token.js                           # Token generation
    ├── notify.js                          # Notifications
    ├── callAccepted.js                    # Call accepted
    ├── callDeclined.js                    # Call declined
    └── endCall.js                         # End call
```

---

## 💻 Development Workflow

### Starting Your Day

```bash
# Pull latest changes
git pull origin dev

# Update dependencies
flutter pub get
npm install

# Rebuild generated code (if needed)
flutter pub run build_runner build

# Start local servers
# Terminal 1
cd livekit
netlify dev

# Terminal 2
cd ../livekit_calling_app
flutter run
```

### Making Changes

```bash
# Create feature branch
git checkout -b feature/your-feature

# Make changes and test
# Use hot reload: press 'r' in Flutter terminal

# Commit changes
git add .
git commit -m "feat: add your feature"

# Push and create PR
git push origin feature/your-feature
```

### Code Review Checklist

Before committing:
- [ ] Code follows Dart style guide
- [ ] No console errors or warnings
- [ ] All tests pass
- [ ] No hard-coded values
- [ ] Comments added for complex logic
- [ ] Dependencies updated in pubspec.yaml

---

## 🎓 Learning Resources

### Flutter Basics
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Guide](https://dart.dev/guides)
- [Widget Catalog](https://flutter.dev/docs/development/ui/widgets)

### Firebase
- [Firebase Console](https://console.firebase.google.com)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Firestore Data Model](https://firebase.google.com/docs/firestore/data-model)

### Real-time Communication
- [LiveKit Documentation](https://docs.livekit.io)
- [WebRTC Concepts](https://webrtc.org)
- [Firebase Messaging](https://firebase.google.com/docs/cloud-messaging)

### Project-Specific
- Read our [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md)
- Review [API_REFERENCE.md](./API_REFERENCE.md)
- Check [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)

---

## 🔑 Key Concepts

### Authentication Flow
1. User taps "Sign in with Google/Apple"
2. OAuth dialog opens
3. User grants permission
4. Firebase Auth creates user
5. App stores ID token
6. Token auto-refreshes before expiry

**Key File**: `lib/helpers/social_auth.dart`

### Calling Flow
1. User initiates call → creates call doc in Firestore
2. Sends notification to recipient
3. Recipient accepts → updates call status
4. Both request access token from backend
5. Connect to LiveKit room
6. WebRTC streams established
7. End call → cleanup and notify

**Key Files**:
- `lib/features/home/presentation/home.dart` - Call initiation
- `livekit/netlify/functions/token.js` - Token generation
- `lib/features/call/` - Call screen

### Notification Flow
1. Call initiated
2. Backend queries FCM tokens from Firestore
3. Firebase Cloud Messaging sends notification
4. Platform-specific handling (iOS/Android)
5. App receives notification
6. Notification handler updates UI

**Key File**: `lib/helpers/notification_service.dart`

### State Management
Uses **Provider** pattern for:
- Authentication state
- Call state (incoming, ongoing, ended)
- User list
- Network state

**Key File**: `lib/providers/call_state_provider.dart`

---

## 🐛 Common Development Issues

### Hot Reload Not Working
```bash
# Solution: Hot restart instead
# Press 'R' instead of 'r'
# Or rebuild the app
flutter clean
flutter run
```

### Firebase Not Initialized
```bash
# Ensure main.dart has:
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform
);
```

### Token Expired
```dart
# Dio interceptor handles this automatically:
# Each request calls user.getIdToken() which auto-refreshes
```

### Notification Not Received
1. Check permissions granted
2. Verify FCM token synced
3. Check Firestore has fcmTokens for user
4. Test with Firebase Console notification

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for more issues.

---

## 📊 Code Quality Standards

### Naming Conventions
```dart
// Variables: camelCase
String userName = "John";
int userAge = 25;

// Constants: camelCase with 'k' prefix
const String kKeyAccessToken = 'access_token';

// Classes: PascalCase
class LoginScreen extends StatefulWidget {}

// Functions: camelCase
Future<void> initializeApp() {}

// File names: snake_case
login_screen.dart
```

### Code Organization
```dart
// 1. Imports
import 'package:flutter/material.dart';

// 2. Constants
const double kPadding = 16.0;

// 3. Class definition
class MyWidget extends StatelessWidget {
  // 4. Properties
  final String title;
  
  // 5. Constructor
  const MyWidget({required this.title});
  
  // 6. Methods
  @override
  Widget build(BuildContext context) {
    // Implementation
  }
}
```

### Error Handling
```dart
try {
  final result = await someAsyncOperation();
  return result;
} on SpecificException catch (e) {
  // Handle specific exception
  print('Error: $e');
  rethrow; // or return default value
} catch (e) {
  // Handle generic exceptions
  print('Unknown error: $e');
}
```

---

## 🧪 Testing

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/unit/auth_test.dart

# Run with coverage
flutter test --coverage
```

### Writing Tests
```dart
void main() {
  group('Authentication Tests', () {
    test('User can sign in with Google', () async {
      // Arrange
      final auth = MockFirebaseAuth();
      
      // Act
      final result = await signInWithGoogle();
      
      // Assert
      expect(result, isNotNull);
      expect(result.uid, isNotEmpty);
    });
  });
}
```

---

## 🚀 Deployment Checklist

Before deploying to production:

### Code
- [ ] All tests pass
- [ ] No console errors or warnings
- [ ] Code reviewed and approved
- [ ] Dependencies updated to latest stable
- [ ] No hard-coded URLs or secrets

### Configuration
- [ ] Environment variables set correctly
- [ ] Firebase project configured
- [ ] LiveKit credentials updated
- [ ] API endpoints verified
- [ ] CORS configured

### Mobile
- [ ] App icon and splash screen set
- [ ] Version number updated
- [ ] Build number incremented
- [ ] Signing certificates valid
- [ ] All platform-specific configs updated

### Backend
- [ ] Netlify environment variables set
- [ ] Functions tested in production
- [ ] Firestore rules deployed
- [ ] Database indexes created
- [ ] Monitoring enabled

### QA
- [ ] Manual testing on real devices
- [ ] All features tested
- [ ] Edge cases handled
- [ ] Notifications working
- [ ] Crash reporting enabled

See [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md) for deployment steps.

---

## 📞 Team Communication

### Getting Help
1. Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) first
2. Ask on team Slack/Discord
3. Create an issue in GitHub
4. Mention @maintainers for urgent issues

### Asking Good Questions
```
❌ Bad: "Why doesn't this work?"

✅ Good: "I'm getting 'Permission denied' error when 
trying to read from Firestore. Here's my code: [code snippet]. 
I've already checked the security rules and they look correct."
```

### Code Review
- Be respectful and constructive
- Ask questions instead of making demands
- Approve once satisfied with changes
- Mark as approved before merge

---

## 📈 Performance Tips

### Mobile App
1. Use `const` constructors
2. Avoid rebuilds with Provider
3. Lazy load lists with ListView.builder
4. Cache API responses
5. Use split APKs for Android

### Backend
1. Cache tokens before expiry
2. Use indexed Firestore queries
3. Limit document reads per request
4. Implement rate limiting
5. Monitor function execution time

### Network
1. Compress images before upload
2. Use appropriate API pagination
3. Cache responses on client
4. Implement retry logic
5. Monitor latency

---

## 🔒 Security Reminders

### Never
❌ Commit private keys or tokens
❌ Hard-code API endpoints
❌ Log sensitive data
❌ Use plaintext for storage
❌ Skip input validation

### Always
✅ Use environment variables
✅ Validate server-side
✅ Encrypt sensitive data
✅ Use HTTPS/WSS
✅ Follow least privilege principle

---

## 🎯 Your First Task

As a new developer, start with:

1. **Setup** (Day 1-2)
   ```bash
   # Complete QUICK_START.md
   # Get app running locally
   # Test with another device
   ```

2. **Code Exploration** (Day 3-4)
   - Read `lib/main.dart`
   - Understand authentication flow
   - Review HomeScreen implementation
   - Study notification handling

3. **Small Contribution** (Day 5)
   - Fix a small bug
   - Add a feature to UI
   - Write a test
   - Create your first PR

---

## 📚 Documentation Index

Use this index to find information quickly:

| Topic | Document | Section |
|-------|----------|---------|
| Getting Started | QUICK_START.md | - |
| Architecture | SYSTEM_DESIGN.md | Architecture Overview |
| Database Schema | SYSTEM_DESIGN.md | Database Schema |
| API Endpoints | API_REFERENCE.md | API Endpoints |
| Code Structure | IMPLEMENTATION_GUIDE.md | Flutter App Structure |
| Setup Instructions | IMPLEMENTATION_GUIDE.md | Project Setup |
| Troubleshooting | TROUBLESHOOTING.md | Troubleshooting Guide |
| FAQ | TROUBLESHOOTING.md | FAQ |

---

## 💡 Pro Tips

1. **Use `flutter run` with `-v` flag for verbose output**
   ```bash
   flutter run -v
   # Helps debug issues
   ```

2. **Hot reload vs Hot restart**
   ```bash
   # 'r' = hot reload (preserves state, faster)
   # 'R' = hot restart (rebuilds everything)
   ```

3. **Check logs regularly**
   ```bash
   flutter logs              # App logs
   firebase functions:log    # Backend logs
   netlify logs:functions    # Netlify logs
   ```

4. **Use breakpoints for debugging**
   - Click line number in VS Code
   - Set condition for conditional breakpoints
   - Step through code with F10/F11

5. **Test on physical devices early**
   - Emulators don't always match real behavior
   - Notifications work differently
   - Performance varies

---

## 🎓 Learning by Doing

### Exercise 1: Add a New Feature to UI
**Goal**: Add a "Settings" button to home screen

Steps:
1. Create `settings.dart` in `lib/features/`
2. Add settings route in navigation
3. Implement settings UI
4. Test on device

### Exercise 2: Create a Backend Function
**Goal**: Add a function to block a user

Steps:
1. Create `blockUser.js` in `netlify/functions/`
2. Verify Firebase ID token
3. Update Firestore user document
4. Return success response
5. Call from app

### Exercise 3: Write Tests
**Goal**: Write unit tests for authentication

Steps:
1. Create `test/unit/social_auth_test.dart`
2. Mock Firebase Auth
3. Test SignIn functions
4. Test error handling

---

## 🚀 Next Steps

1. **This Week**
   - Complete onboarding
   - Get environment running
   - Explore codebase

2. **Next Week**
   - Contribute small changes
   - Participate in code reviews
   - Ask questions

3. **Month 1**
   - Take ownership of a feature
   - Improve documentation
   - Help onboard next developer

---

## 🎉 Welcome to the Team!

You now have:
- ✅ Complete documentation
- ✅ Setup instructions
- ✅ Architecture overview
- ✅ Development resources
- ✅ Troubleshooting guides

**You're ready to start coding!** 🚀

---

## Questions?

1. **"How do I run the app?"** → [QUICK_START.md](./QUICK_START.md)
2. **"How does it work?"** → [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md)
3. **"How do I code?"** → [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)
4. **"What's the API?"** → [API_REFERENCE.md](./API_REFERENCE.md)
5. **"Something's broken"** → [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)

---

**Happy coding! Welcome aboard! 🎉**

