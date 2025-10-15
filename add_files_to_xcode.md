# How to Add Files to Xcode Project

The authentication system files have been created and are now in the correct location:
`/Users/pranish/Documents/Homi/Homi/Homi/`

## Directory Structure Created:
```
Homi/Homi/Homi/
├── App/
│   ├── HomiApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── User.swift
│   └── House.swift
├── Views/
│   ├── Auth/
│   │   ├── WelcomeView.swift
│   │   ├── AuthOptionsView.swift
│   │   ├── PhoneAuthView.swift
│   │   ├── EmailSignUpView.swift
│   │   └── ProfileSetupView.swift
│   └── Main/
│       └── ContentView.swift
├── ViewModels/
│   └── AuthViewModel.swift
├── Services/
│   ├── AuthService.swift
│   └── FirestoreService.swift
└── Utilities/
    └── Constants.swift
```

## To Add These Files to Xcode:

1. Open your Xcode project
2. In the project navigator (left sidebar), right-click on the "Homi" folder (the one that contains Assets.xcassets)
3. Select "Add Files to 'Homi'..."
4. Navigate to: `/Users/pranish/Documents/Homi/Homi/Homi/`
5. Select all these folders:
   - App
   - Models
   - Views
   - ViewModels
   - Services
   - Utilities
6. Make sure these options are set:
   - ✅ "Create groups" (not "Create folder references")
   - ❌ "Copy items if needed" (unchecked - files are already in the right place)
   - ✅ Add to target: "Homi"
7. Click "Add"

## After Adding Files:

1. You may need to update the import statements in HomiApp.swift since ContentView is now in Views/Main/
2. Build the project (Cmd+B) to ensure everything compiles
3. The authentication system is now ready to use!

## Features Implemented:

✅ Complete authentication system with:
- Email/Password sign up and sign in
- Phone number authentication with SMS OTP
- Apple Sign In
- Google Sign In (ready, needs SDK configuration)
- Profile setup with photo upload
- User session management
- Firebase Firestore integration

The app will automatically show the authentication flow for new users and transition to the main app after successful sign in.