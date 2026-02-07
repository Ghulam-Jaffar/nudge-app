# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nudge is a social reminder app for Gen Z built with Flutter and Firebase. Users create personal reminders and shared spaces where members collaborate on items and get notified.

**Firebase project:** `e-nudge`

## Commands

```bash
# Flutter app
flutter pub get                    # Install dependencies
flutter run -d chrome              # Run on web
flutter run -d windows             # Run on Windows
flutter run -d android             # Run on Android
flutter analyze                    # Lint/static analysis
flutter test                       # Run tests

# Code generation (Riverpod/JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# Firebase deployment
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only functions

# Cloud Functions (in functions/ directory)
cd functions && npm run build      # Compile TypeScript
cd functions && npm run deploy     # Deploy functions
cd functions && npm run serve      # Local emulator
```

## Architecture

**Data flow:** `Firestore streams → Services (business logic) → Providers (Riverpod) → Screens (ConsumerWidget)`

### Layers

- **Models** (`lib/models/`): Immutable Equatable data classes with `fromFirestore`/`fromMap` factory constructors, `toMap()` serialization, and `copyWith()`. Barrel-exported via `models.dart`.
- **Services** (`lib/services/`): Stateless business logic classes that perform Firestore CRUD, notifications, and transactions. Barrel-exported via `services.dart`.
- **Providers** (`lib/providers/`): Riverpod glue layer. `StreamProvider` for real-time Firestore data, `StateNotifierProvider` for theme, `Provider` for service singletons, `.family` for parameterized queries (e.g., space items by spaceId). Barrel-exported via `providers.dart`.
- **Screens** (`lib/screens/`): UI layer using `ConsumerWidget`. Uses `ref.watch()` with `.when(data/loading/error)` pattern for async data.

### Navigation

GoRouter with auth-aware redirects in `lib/router.dart`:
- Unauthenticated → `/auth` (welcome)
- Authenticated without handle → `/auth/setup-handle`
- Authenticated with handle → `/` (home)
- `ShellRoute` wraps the bottom nav tabs (`/`, `/spaces`, `/profile`)
- Detail routes (`/spaces/:spaceId`, `/invites`) are outside the shell

### Notification System

Dual system:
1. **Local notifications** (`LocalNotificationService`): Scheduled reminders on-device via `flutter_local_notifications`
2. **FCM** (`FCMService`): Remote push via Firebase Cloud Messaging
3. **Cloud Functions** (`functions/src/index.ts`): Server-side cron (`sendScheduledReminders` every 1min) queries items where `remindAt <= now && notifyStatus == "scheduled"`, sends FCM to relevant users, marks as `"sent"`

Background handler `firebaseMessagingBackgroundHandler` is a top-level function (required by FCM).

### Theme System

6 theme packs (Candy, Midnight, Matcha, Ocean, Lavender, Sunset) in `lib/theme/theme_packs.dart`. Material 3 with `ColorScheme`. Per-user persistence in Firestore. Managed by `ThemeNotifier` (StateNotifier).

## Firestore Collections

| Collection | Key fields | Notes |
|---|---|---|
| `users` | uid, handle, displayName, fcmTokens, theme | Handle is globally unique |
| `handles` | handle_lower → uid | Uniqueness registry, updated via transactions |
| `items` | type (personal/space), ownerUid, spaceId, remindAt, notifyStatus | Dual-type: personal or space |
| `spaces` | name, emoji, ownerUid, members (Map with roles) | Members map: `{uid: {role, joinedAt}}` |
| `spaceInvites` | fromUid, toUid, spaceId, status | Immutable audit trail (no deletes) |
| `spaceActivities` | spaceId, actorUid, type, targetUid | 18 activity types |
| `pings` | fromUid, toUid, spaceId, itemId | Nudge notifications between members |

## Key Patterns

- All Firestore write operations use **transactions or batches** for atomicity
- Handle reservation uses Firestore transactions to prevent race conditions
- Models use **Equatable** for value equality (important for Riverpod rebuild optimization)
- Services are injected via Riverpod `Provider` and can depend on each other (e.g., `ItemService` depends on `ActivityService`)
- Offline detection via `connectivity_plus` with a banner in `HomeShell`

## Files Not in Version Control

These must be obtained/generated separately:
- `lib/firebase_options.dart` — run `flutterfire configure --project=e-nudge`
- `android/app/google-services.json` — from Firebase Console
- `ios/Runner/GoogleService-Info.plist` — from Firebase Console
- `android/key.properties` and `*.jks` — signing keys
