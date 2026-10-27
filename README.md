# Khaata — Shared Room Ledger & Expense Tracker

[![Flutter](https://img.shields.io/badge/Flutter-3.41.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11.0-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-blue)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A minimal, real-time shared expense tracker and room ledger built with Flutter and Cloud Firestore. **Khaata** enables roommates, couples, and teams to track shared living costs, manage cash deposits/withdrawals, and archive monthly statements with zero friction.

---

## Key Features

### 1. Shared Rooms (2 to 10 Members)
- **Custom Capacity**: Create rooms and select maximum room size (2–10 members) with an intuitive step-slider (`+` / `-`).
- **Easy Invitation**: Each room receives a unique 6-character invite code (e.g., `7K2M9P`). Anyone with the code can join in seconds.
- **Member Directory**: Room Info modal lists all active member names and room details.

### 2. Deliberate Room Reordering
- **Front-Screen Custom Order**: Rearrange your rooms with an intentional 1-second hold to drag cards up or down.
- **Scroll-Safe Interaction**: Quick taps open rooms instantly, and normal scrolling never accidentally triggers reordering.
- **Persistent Ordering**: Your room order is preserved across app close and restarts via `SharedPreferences` and synchronized to your Firestore user profile.

### 3. Real-Time Monthly Expense Ledger
- **Live Sync**: Powered by Cloud Firestore `StreamBuilder` for instant live updates across all devices.
- **Monthly Totals**: Prominent monthly header with automated formula calculation:
  $$\text{Monthly Total} = \sum(\text{Expenses}) - \sum(\text{Withdrawals})$$
- **Date Grouping**: Transactions are organized newest first, neatly grouped by calendar day (e.g., `26 Oct`, `24 Oct`).
- **Dynamic Recalculations**: Instant mathematical recalculation upon adding, editing, or deleting entries.

### 4. Cash Pool / Petty Cash (Pending Amount)
- Dedicated **Cash** tracker accessible directly from the room's AppBar.
- Large **PENDING AMOUNT** balance showing the current net physical cash held:
  $$\text{Pending Cash} = \sum(\text{Deposits}) - \sum(\text{Withdrawals})$$
- Quick operations: **`[ + DEPOSIT ]`** and **`[ - WITHDRAW ]`** with live balance updates.

### 5. Udhaar Tab (Personal Credit & Debit Ledger)
- Accessible via the **Udhaar** icon directly on the left of the Log Out button on the front screen.
- **Vertical Contact List**: Add persons with an initial zero balance (`₹0`).
- **Interactive Quick-Signs**: Front screen shows the person's name on the left and the net amount left between `[-]` and `[+]` buttons.
- **Color Coded Balances**:
  - **Green** for positive balances (money owed to you)
  - **Red** for negative balances (money you owe)
  - **Black** for zero (`₹0`)
- **Quick Modals**: Clicking `+` or `-` prompts for Amount, Note, and Date to instantly update the running total.
- **Transaction History**: Tap any person's name to view their full transaction ledger with dates, descriptions, and delete options.

### 6. Month Completion & Two-Way Swap/Restore
- **Done For This List**: Mark the active month finished to lock its ledger into history.
- **Automatic Rollover**: Automatically initializes the next calendar month at `₹0.00`.
- **Two-Way Restore**: Accidentally closed a month? Restore any archived month back to the active front screen with a single tap, swapping the current list into the archive automatically.
- **Past Month Editing**: Modify or add missed receipts to previous months anytime.

### 7. Seamless Authentication & Privacy
- **Google Sign-In & Phone OTP**: Fast login with Google or SMS verification code.
- **No-Flicker Session Restoration**: Remembers logged-in users and transitions immediately to the front screen without flashing the login screen.
- **Clean Profile Customization**: Tap your name on the front screen to edit your display name. Phone numbers and email addresses remain hidden for privacy.
- **One-Time Welcome Prompt**: Brand new accounts are automatically prompted once for their name.

### 8. Export & Sharing
- **CSV Export**: Export any active or historical monthly ledger to CSV format with a complete mathematical summary.

---

## Architecture & Project Structure

```
expense_tracker/
├── lib/
│   ├── firebase_options.example.dart   # Template for Firebase credentials
│   ├── main.dart                       # App entry point, theme & route setup
│   ├── models/                         # Strongly-typed data models
│   │   ├── cash_transaction_model.dart
│   │   ├── group_model.dart
│   │   ├── month_model.dart
│   │   ├── transaction_model.dart
│   │   └── user_model.dart
│   ├── screens/                        # UI Screens & Dialogs
│   │   ├── auth/                       # Phone & Google authentication
│   │   ├── cash/                       # Cash pool / pending balance tab
│   │   ├── expense/                    # Monthly expense list, details & modals
│   │   └── groups/                     # Room list, reordering, create & join
│   ├── services/                       # Business logic & data access
│   │   ├── auth_service.dart           # User auth & profile sync
│   │   ├── expense_service.dart        # Firestore expenses & months
│   │   ├── export_service.dart         # CSV generation & file sharing
│   │   └── group_service.dart          # Rooms, memberships & ordering
│   └── widgets/                        # Reusable UI components
├── test/
│   └── widget_test.dart                # Comprehensive suite of 17 automated tests
├── android/
├── ios/
├── web/
├── windows/
├── firestore.rules                     # Cloud Firestore security rules
└── pubspec.yaml                        # Dependencies and assets
```

---

## Cloud Firestore Schema

```
users/{userId}
  ├── name: string
  ├── phoneNumber: string
  ├── groupOrder: array of groupIds
  └── createdAt: timestamp

groups/{groupId}
  ├── name: string
  ├── inviteCode: string
  ├── members: array of userIds
  ├── maxMembers: number (2 to 10)
  ├── createdAt: timestamp
  │
  ├── cash/summary
  │     ├── pendingAmount: number
  │     └── updatedAt: timestamp
  │
  ├── cash_transactions/{transactionId}
  │     ├── type: 'deposit' | 'withdraw'
  │     ├── amount: number
  │     ├── description: string
  │     ├── date: timestamp
  │     ├── createdBy: userId
  │     └── createdAt: timestamp
  │
  └── months/{YYYY-MM}
        ├── total: number
        ├── status: 'active' | 'done'
        ├── createdAt: timestamp
        ├── completedAt: timestamp?
        │
        └── transactions/{transactionId}
              ├── name: string
              ├── amount: number
              ├── type: 'expense' | 'withdrawal'
              ├── date: timestamp
              ├── createdBy: userId
              └── createdAt: timestamp
```

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.3.0`)
- A Firebase account with a Firestore Database enabled

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/expense_tracker.git
   cd expense_tracker
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**:
   
   **Option A — Automated (Recommended)**:
   Install the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) and run:
   ```bash
   flutterfire configure
   ```

   **Option B — Manual Setup**:
   - Copy the Firebase options template:
     ```bash
     cp lib/firebase_options.example.dart lib/firebase_options.dart
     ```
   - For Android, download `google-services.json` from the Firebase Console and place it at:
     ```
     android/app/google-services.json
     ```
     *(A reference template is available at `android/app/google-services.json.example`)*
   - For iOS, place `GoogleService-Info.plist` at:
     ```
     ios/Runner/GoogleService-Info.plist
     ```

4. **Deploy Firestore Security Rules**:
   ```bash
   firebase deploy --only firestore:rules
   ```

5. **Run the application**:
   ```bash
   # Run on connected device or emulator
   flutter run

   # Or run on Chrome / Windows desktop
   flutter run -d chrome
   flutter run -d windows
   ```

---

## Running Automated Tests

The project includes 17 automated tests covering authentication, Google sign-in, room reordering, cash deposits, CSV exports, and list swaps:

```bash
flutter test
```

To run static analysis:
```bash
flutter analyze
```

---

## Security & Sensitive Information

This repository is configured with a secure `.gitignore`:
- Private Firebase credentials (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`) are excluded from version control.
- Android signing keystores (`*.jks`, `*.keystore`, `key.properties`, `local.properties`) and environment files (`.env*`) are ignored.
- Build artifacts, IDE workspaces (`.idea/`, `.vscode/`, `*.iml`), and ephemeral files are ignored.

---

## License

This project is open-source under the [MIT License](LICENSE).
