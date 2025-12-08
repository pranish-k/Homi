# Homi

A comprehensive iOS roommate management app built with SwiftUI and Firebase. Homi helps households manage shared expenses, chores, communication, and coordination in one place.

## Features

<img src="https://github.com/user-attachments/assets/14e236fe-6613-4da3-82f8-b3b351814298" width="250" alt="Home Screen">

### Expense Management

<img src="https://github.com/user-attachments/assets/814da67a-03a4-4b87-8bbb-3023566b4704" width="250" alt="Expense Management">

- Track shared expenses with categories (Rent, Utilities, Groceries, Supplies, Internet, Cleaning, Maintenance)
- Smart bill splitting with equal or custom split amounts
- Real-time balance calculations between all roommates
- Payment recording with multiple methods (Cash, Venmo, Zelle, Cash App, Bank Transfer, Check)
- Partial payment tracking and settlement history
- Automated payment allocation to oldest expenses first

### Chore Management

<img src="https://github.com/user-attachments/assets/1a086072-4a2d-4160-ac1a-474555919f62" width="250" alt="Chore Management">

- Assign tasks to specific roommates
- Support for one-time, daily, weekly, bi-weekly, and monthly frequencies
- Categories including Cleaning, Kitchen, Bathroom, Trash, Outdoor, Pets, and Laundry
- Automatic rotation for recurring chores
- Completion tracking with timestamps

### Messaging

<img src="https://github.com/user-attachments/assets/b2edb134-c595-47e5-8774-d10a76ac8efc" width="250" alt="Messaging">

- House-wide group chat
- Private direct messages between housemates
- Support for text and image messages
- Read receipts

### Location Sharing

<img src="https://github.com/user-attachments/assets/96a34efe-a3d1-4fac-9706-c6c84f24688e" width="250" alt="Location Sharing">

- Real-time location sharing with housemates
- Map view of member locations
- Privacy controls with opt-in sharing

### House Management

- Create and join households via invite codes
- Member management and role assignment
- Nudge system for friendly payment reminders

## Technical Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI (iOS 17.0+) |
| Architecture | MVVM |
| Backend | Firebase (Auth, Firestore, Storage) |
| Authentication | Email, Phone OTP, Google Sign-In, Apple Sign-In |
| State Management | Combine Framework |
| Crash Reporting | Firebase Crashlytics |

## Project Structure
```
Homi/
├── App/
│   ├── HomiApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── Expense.swift
│   ├── Chore.swift
│   ├── User.swift
│   ├── House.swift
│   └── Message.swift
├── Services/
│   ├── AuthService.swift
│   ├── FirestoreService.swift
│   ├── ExpenseService.swift
│   ├── CentralExpenseStore.swift
│   ├── ChoreService.swift
│   ├── MessagingService.swift
│   └── LocationService.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ExpenseViewModel.swift
│   ├── ChoreViewModel.swift
│   └── DashboardViewModel.swift
├── Views/
│   ├── Auth/
│   ├── Main/
│   ├── Expenses/
│   ├── Chores/
│   ├── Messages/
│   ├── Location/
│   ├── Settings/
│   └── Components/
└── Utilities/
    ├── Constants.swift
    ├── ThemeManager.swift
    ├── CurrencyFormatter.swift
    └── HapticManager.swift
```

## Key Technical Implementations

### Financial Precision
Uses integer-based calculations (cents) to avoid floating-point precision errors in expense splitting:
```swift
let totalCents = Int(round(amount * 100))
let baseSplit = totalCents / participantCount
let remainder = totalCents % participantCount
```

### Payment Deduplication
Idempotency keys prevent duplicate payments within a 10-second window:
```swift
idempotencyKey = "\(user1)_\(user2)_\(amountCents)_\(timestamp / 10000)"
```

### Optimistic UI Updates
Immediate UI feedback with automatic rollback on failure for responsive user experience.

### Central State Store
Single source of truth pattern for expense data using `CentralExpenseStore` to prevent listener conflicts and ensure data consistency.

### App Lifecycle Management
Intelligent Firestore listener management that pauses in background to conserve battery and resumes when app becomes active.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Firebase project with Firestore, Authentication, and Storage enabled

## Architecture

The app follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: Data structures for expenses, chores, users, houses, and messages
- **Views**: SwiftUI views organized by feature
- **ViewModels**: Observable objects managing state and business logic
- **Services**: Singleton services handling Firebase operations and data management

## Data Flow

1. Views observe ViewModels via `@StateObject` and `@ObservedObject`
2. ViewModels subscribe to `CentralExpenseStore` for expense data
3. Services handle Firestore reads/writes and real-time listeners
4. Combine framework enables reactive data binding with `@Published` properties

## License

All rights reserved.
