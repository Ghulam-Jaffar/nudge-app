# Nudge

**A social reminder app for Gen Z** - Create personal reminders and shared lists where everyone gets notified.

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## ✨ Features

### Personal Reminders
- 📝 Create personal todo items and reminders
- ⏰ Set custom notification times with timezone support
- 🔁 Recurring reminders (daily, weekly, monthly)
- 🎯 Priority levels (none, low, medium, high)
- ✅ Mark items as complete with completion tracking

### Shared Spaces
- 👥 Create collaborative reminder spaces with friends
- 🔔 Everyone in the space gets notified
- 👤 Role-based permissions (owner, admin, member)
- 💬 Real-time updates across all devices
- 🎨 Custom space names and emojis

### Social Features
- 🔍 Find friends by unique handle (@username)
- 📨 Send and receive space invitations
- 👋 Google Sign-In integration
- 📧 Email/password authentication
- 🖼️ Profile customization with display names and avatars

### Notifications
- 🔔 Push notifications via Firebase Cloud Messaging
- 📱 Local notifications for scheduled reminders
- 🌐 Cross-platform support (Android, iOS, Web, Windows, macOS)

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev) 3.10+
- **Language:** Dart
- **Backend:** Firebase
  - Authentication (Email/Password + Google Sign-In)
  - Cloud Firestore (NoSQL database)
  - Cloud Messaging (Push notifications)
  - Cloud Storage (File uploads)
- **State Management:** Riverpod 2.6+
- **Navigation:** GoRouter 14.6+
- **Local Notifications:** flutter_local_notifications
- **UI:** Material Design 3

---

## 📱 Supported Platforms

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ⚠️ Linux (partial support)

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.10.7 or higher
- Dart SDK (included with Flutter)
- Firebase account
- Android Studio / Xcode (for mobile development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/nudge-app.git
   cd nudge-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   
   You'll need to set up your own Firebase project:
   
   a. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   
   b. Enable the following services:
      - Authentication (Email/Password + Google)
      - Cloud Firestore
      - Cloud Messaging
      - Cloud Storage
   
   c. Install FlutterFire CLI:
      ```bash
      dart pub global activate flutterfire_cli
      ```
   
   d. Configure Firebase for your app:
      ```bash
      flutterfire configure --project=YOUR_PROJECT_ID
      ```
   
   e. Deploy Firestore security rules:
      ```bash
      firebase init firestore
      firebase deploy --only firestore:rules
      ```

4. **Run the app**
   ```bash
   # For web
   flutter run -d chrome
   
   # For Android
   flutter run -d android
   
   # For iOS
   flutter run -d ios
   
   # For Windows
   flutter run -d windows
   ```

---

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Root app widget
├── router.dart               # Navigation configuration
├── firebase_options.dart     # Firebase config (auto-generated)
├── models/                   # Data models
│   ├── user_model.dart
│   ├── space_model.dart
│   ├── item_model.dart
│   └── invite_model.dart
├── providers/                # Riverpod providers
│   ├── auth_provider.dart
│   ├── user_provider.dart
│   └── providers.dart
├── screens/                  # UI screens
│   ├── auth/                 # Authentication screens
│   ├── home/                 # Home screen
│   ├── spaces/               # Space management
│   └── settings/             # Settings screens
├── services/                 # Business logic
│   ├── auth_service.dart
│   ├── user_service.dart
│   ├── space_service.dart
│   ├── item_service.dart
│   ├── invite_service.dart
│   ├── fcm_service.dart
│   └── local_notification_service.dart
└── theme/                    # App theming
    └── app_theme.dart
```

---

## 🔐 Security

- Firebase security rules are implemented for all collections
- API keys and sensitive config files are excluded from git
- User authentication required for all operations
- Role-based access control for shared spaces

**Important:** Never commit these files:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

---

## 🗄️ Database Schema

### Collections

**users**
- User profiles with handles, display names, and FCM tokens

**handles**
- Unique handle registry for username lookups

**spaces**
- Shared reminder spaces with members and roles

**items**
- Personal and space reminder items

**spaceInvites**
- Pending, accepted, and declined space invitations

---

## 🎨 Design Philosophy

Nudge is designed with Gen Z in mind:
- **Minimal friction:** Quick actions, no unnecessary steps
- **Social-first:** Built for sharing and collaboration
- **Modern UI:** Clean, vibrant, and intuitive
- **Gentle nudges:** Reminders that don't nag

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

Built with ❤️ for Gen Z

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend infrastructure
- Riverpod for state management
- The open-source community

---

## 📞 Support

For support, email herojaf12@gmail.com or open an issue in this repository.
