# XanhNow Auth Module

Flutter mobile Auth/Security module for `XanhNow.Security`.

## Backend

Production base URL:

```text
https://api.ioxy.site/security
```

Implemented client flows:

- Password registration.
- Mandatory passkey registration after password registration.
- Password login with `PasskeyRequired` routing.
- Passkey login begin/finish.
- Token refresh with `sessionId`.
- Session list/logout/logout-all.
- Security profile.

## Passkey decision

The app uses the maintained `passkeys` Flutter plugin first. The backend remains the relying party server:

```text
Security API begin -> publicKeyOptions
Flutter passkeys plugin -> platform credential ceremony
Security API finish -> backend verification
```

Use platform channel only if the plugin cannot satisfy production behavior on Android/iOS.

Native setup still required before production:

- Android Digital Asset Links for `api.ioxy.site`.
- iOS Associated Domains / AASA for `api.ioxy.site`.
- Stable app package name / bundle id.
- Release certificate SHA-256 for Android.

## Run

Install Flutter SDK 3.35+ / Dart 3.9+ and run:

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=XANHNOW_SECURITY_BASE_URL=https://api.ioxy.site/security
```
