# BookMe — Flutter Booking App

Personal booking system using Google Calendar + free WhatsApp notifications.

---

## Project Structure

```
lib/
├── main.dart                      # App entry, theme setup
├── models/
│   ├── booking.dart               # Booking data model
│   └── time_slot.dart             # Time slot model
├── services/
│   ├── calendar_service.dart      # Google Calendar API (FreeBusy + events)
│   ├── whatsapp_service.dart      # WhatsApp via Android Intent (free)
│   └── booking_provider.dart     # State management (ChangeNotifier)
├── screens/
│   ├── home_screen.dart           # Bottom nav + Google Sign-In gate
│   ├── book_screen.dart           # Date picker, slots grid
│   ├── upcoming_screen.dart       # Upcoming bookings + WhatsApp reminder
│   └── history_screen.dart        # Past bookings grouped by month
└── widgets/
    ├── slot_chip.dart              # Individual time slot chip
    └── booking_form_sheet.dart    # Bottom sheet booking form
```

---

## Setup (Step-by-Step)

### 1. Install Flutter
```bash
# Download from https://docs.flutter.dev/get-started/install
flutter doctor   # verify installation
```

### 2. Create the project & copy these files
```bash
flutter create bookme
# Replace the lib/ folder and other files with this scaffold
```

### 3. Enable Google Calendar API

1. Go to https://console.cloud.google.com
2. Create a new project → name it "BookMe"
3. Enable **Google Calendar API**
4. Go to **Credentials** → Create **OAuth 2.0 Client ID**
   - Application type: **Android**
   - Package name: `com.example.bookme` (match your app)
   - SHA-1: run `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
5. Also create an **OAuth consent screen** → add your Google account as a test user

### 4. Add OAuth client ID to android/app/build.gradle
```gradle
// No code change needed — google_sign_in reads from google-services.json
```

Download `google-services.json` from the Firebase Console and place it at:
```
android/app/google-services.json
```

Or alternatively, just add your Web Client ID to `android/app/src/main/res/values/strings.xml`:
```xml
<resources>
    <string name="default_web_client_id">YOUR_WEB_CLIENT_ID_HERE</string>
</resources>
```

### 5. Get dependencies
```bash
flutter pub get
```

### 6. Run on Android device/emulator
```bash
flutter run
```

---

## How WhatsApp Works (Free)

No API key needed. The app uses Android's Intent system:

```dart
final uri = Uri.parse('https://wa.me/$phone?text=$encodedMessage');
await launchUrl(uri, mode: LaunchMode.externalApplication);
```

This opens WhatsApp on your phone with the message pre-typed.
You tap **Send** — the message goes from YOUR number. 100% free.

---

## How Google Calendar Works

- **FreeBusy API** — checks your calendar for blocked times, greys out unavailable slots
- **events.insert()** — creates a calendar event with `sendUpdates: 'all'` which automatically emails calendar invites to the guest
- **extendedProperties** — stores guest phone and `bookme_source` tag on each event so the app can query only BookMe events for history/upcoming views

---

## Key Dependencies

| Package | Purpose | Cost |
|---------|---------|------|
| `google_sign_in` | OAuth sign-in | Free |
| `googleapis` | Calendar API client | Free |
| `url_launcher` | WhatsApp Intent | Free |
| `provider` | State management | Free |
| `intl` | Date formatting | Free |
| `flutter_local_notifications` | In-app reminders | Free |

All free. No paid APIs.

---

## Next Steps

- [ ] Add push notifications (Firebase Cloud Messaging — free)
- [ ] Add buffer time between bookings
- [ ] Add recurring booking support
- [ ] Build shareable booking link (web version with FlutterWeb)
- [ ] Add iOS support (same codebase, just register iOS OAuth client)
