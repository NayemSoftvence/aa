# LiveKit Calling App - Quick Start Guide

## 🚀 Get Up and Running in 5 Minutes

### Prerequisites Check
```bash
# Check Flutter installation
flutter doctor

# Check Node.js version
node --version  # Should be >=18

# Check Git
git --version
```

---

## Step 1: Clone & Setup (1 min)

```bash
# Clone repository
git clone <repository-url>
cd calling\ app

# Setup Flutter app
cd livekit_calling_app
flutter pub get
flutter pub run build_runner build

# Setup backend
cd ../livekit
npm install
```

---

## Step 2: Configure Firebase (2 min)

### Get Service Account Key
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: `livekit-calling`
3. Go to **Settings → Service Accounts**
4. Click **Generate New Private Key**
5. Download JSON file

### Encode & Setup Environment
```bash
# In livekit/ directory
# Convert private key to base64
base64 < /path/to/service-account-key.json | pbcopy

# Create .env file
cat > .env << EOF
FIREBASE_PROJECT_ID=livekit-calling
FIREBASE_CLIENT_EMAIL=your-email@xxx.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY_BASE64=<paste-base64-key>
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret
LIVEKIT_URL=ws://localhost:7880
EOF
```

---

## Step 3: Download Firebase Config Files (1 min)

```bash
# From Firebase Console > Project Settings > General
# Download GoogleService-Info.plist for iOS
# Download google-services.json for Android

# Place files in correct locations:
# iOS: livekit_calling_app/ios/Runner/GoogleService-Info.plist
# Android: livekit_calling_app/android/app/google-services.json
```

---

## Step 4: Start Development (1 min)

### Terminal 1: Netlify Functions
```bash
cd livekit
netlify dev
# Functions available at http://localhost:8888
```

### Terminal 2: Flutter App
```bash
cd livekit_calling_app
flutter run
# Choose device/simulator to run on
```

---

## 🎯 First Test Run

### What to Test
1. **Open app** → Should redirect to login screen
2. **Click "Sign in with Google"** → Login with your Google account
3. **After login** → Should show list of online users
4. **Find another user** → Open app on another device/simulator
5. **Click on user** → Should initiate call
6. **Other user** → Should receive incoming call notification
7. **Accept call** → Both should see video stream

---

## 📱 Key Features to Test

| Feature | How to Test |
|---------|------------|
| **Google Sign-In** | Tap "Sign in with Google", complete OAuth flow |
| **Apple Sign-In** | (iOS only) Tap "Sign in with Apple" |
| **User List** | After login, should see online users |
| **Initiate Call** | Tap on user to start call |
| **Receive Call** | Should see incoming call notification |
| **Accept Call** | Tap "Accept" to join call |
| **Video Stream** | Both users should see each other |
| **End Call** | Tap "End Call" button |
| **Notifications** | App in foreground & background both |

---

## 🐛 Common Setup Issues

### Issue: "Flutter SDK not found"
```bash
# Solution: Install Flutter
# Or add to PATH
export PATH="$PATH:~/flutter/bin"
```

### Issue: "Pod install failed" (iOS)
```bash
cd ios
pod repo update
pod install
cd ..
```

### Issue: "Google Services JSON not found" (Android)
```bash
# Verify file exists at:
ls android/app/google-services.json

# If not found:
# 1. Download from Firebase Console
# 2. Place in android/app/ directory
```

### Issue: "Netlify functions not accessible"
```bash
# Ensure running from livekit directory
cd livekit
netlify dev

# Verify at: http://localhost:8888
```

### Issue: "FCM Token error"
```bash
# Solution: 
# 1. Check permissions are granted to app
# 2. Ensure Firebase Messaging initialized
# 3. Wait 30 seconds after login
```

---

## 📂 Important Directories

| Directory | Purpose |
|-----------|---------|
| `livekit_calling_app/lib/` | Flutter app source code |
| `livekit_calling_app/lib/features/` | Feature modules (auth, call, home) |
| `livekit_calling_app/lib/helpers/` | Utilities (auth, notifications, DI) |
| `livekit/netlify/functions/` | Serverless backend functions |
| `livekit_calling_app/android/` | Android-specific code |
| `livekit_calling_app/ios/` | iOS-specific code |

---

## 🔑 Key Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `pubspec.yaml` | Flutter dependencies | `livekit_calling_app/` |
| `package.json` | Node dependencies | `livekit/` |
| `firebase.json` | Firebase config | `livekit_calling_app/` |
| `firebase_options.dart` | Firebase initialization | `livekit_calling_app/lib/` |
| `.env` | Environment variables | `livekit/` |

---

## 📚 Documentation Files in Project

1. **SYSTEM_DESIGN.md** - Architecture & design decisions
2. **IMPLEMENTATION_GUIDE.md** - Detailed development guide
3. **This file** - Quick start guide
4. **README.md** (in each folder) - Module-specific docs

---

## 🚢 Next Steps

### For Development
1. Review `SYSTEM_DESIGN.md` for architecture
2. Read `IMPLEMENTATION_GUIDE.md` for detailed setup
3. Explore `lib/features/` to understand code structure
4. Check `lib/helpers/` for utility functions

### For Deployment
1. Build release APK: `flutter build apk --release`
2. Build release IPA: `flutter build ipa --release`
3. Deploy backend: `netlify deploy --prod`
4. Submit to App Stores

### For Contributions
1. Create feature branch: `git checkout -b feature/your-feature`
2. Make changes and commit: `git commit -am "Add feature"`
3. Push and create PR: `git push origin feature/your-feature`
4. Follow code style guidelines

---

## 💡 Tips & Tricks

### Hot Reload Development
```bash
flutter run
# Press 'r' to hot reload
# Press 'R' for hot restart
# Press 'q' to quit
```

### View Logs
```bash
# Flutter logs
flutter logs

# Filter by tag
flutter logs --tags="MyApp"

# Netlify function logs
netlify logs:functions

# Firebase function logs
firebase functions:log
```

### Test on Physical Device
```bash
# iOS
open ios/Runner.xcworkspace
# Then select your device and run

# Android
flutter run  # Will auto-detect connected device
```

### Multiple Simulators
```bash
# iOS - Start specific simulator
open -a Simulator

# Android - List available emulators
flutter emulators

# Run on specific emulator
flutter run -d <emulator-id>
```

---

## 📞 Support

### Documentation
- [System Design](./SYSTEM_DESIGN.md) - High-level architecture
- [Implementation Guide](./IMPLEMENTATION_GUIDE.md) - Detailed technical guide
- [Flutter Docs](https://flutter.dev)
- [Firebase Docs](https://firebase.google.com/docs)
- [LiveKit Docs](https://docs.livekit.io)

### Debugging
- Check Flutter logs: `flutter logs`
- Check Firebase Console for errors
- Check Netlify Function logs
- Review console output in terminal

---

## ✅ Checklist Before Running

- [ ] Flutter SDK installed and in PATH
- [ ] Node.js >=18 installed
- [ ] Git installed
- [ ] Firebase CLI installed
- [ ] Cloned repository
- [ ] Downloaded Firebase credentials
- [ ] Set environment variables
- [ ] Ran `flutter pub get`
- [ ] Ran `flutter pub run build_runner build`
- [ ] Ran `npm install` in livekit/
- [ ] Started Netlify dev server
- [ ] Started Flutter app

---

**You're all set! Happy coding! 🎉**

