# Authentication Troubleshooting Guide

## Current Status
- ✅ Firebase project configured
- ✅ Authentication methods enabled in Firebase Console
- ✅ Firestore database created
- ✅ Manual Firestore users can login
- ❌ Sign-up not creating Firestore documents

## Debug Steps

### 1. Check Firestore Rules
In Firebase Console > Firestore > Rules, make sure you have permissive rules for testing:

```javascript
// Temporary rules for testing (NOT for production!)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

Or more secure rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own document
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // Allow reading houses if authenticated
    match /houses/{document=**} {
      allow read, write: if request.auth != null;
    }

    // Allow reading invites
    match /invites/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### 2. Check Console Logs
When you try to sign up, check Xcode console for:
- "Starting sign up for email: ..."
- "Firebase Auth user created with ID: ..."
- "Creating user profile for ID: ..."
- "User data: ..."
- Any error messages

### 3. Verify in Firebase Console
After attempting sign-up:
1. Go to Authentication > Users - Check if user appears here
2. Go to Firestore > Data - Check if user document was created

### 4. Test Firestore Directly
Add this test button to ContentView temporarily:

```swift
Button("Test Firestore Write") {
    Task {
        let db = Firestore.firestore()
        do {
            try await db.collection("test").document("test").setData([
                "message": "Test from app",
                "timestamp": Date()
            ])
            print("Firestore write successful!")
        } catch {
            print("Firestore write failed: \(error)")
        }
    }
}
```

### 5. Common Issues & Solutions

#### "Missing or insufficient permissions"
- Update Firestore rules to be more permissive for testing
- Make sure you published the rules (click "Publish" after editing)

#### "An internal error has occurred"
- Check GoogleService-Info.plist is the latest version
- Verify bundle ID matches exactly
- Check API keys are valid in Firebase Console

#### Authentication works but no Firestore document
- Check the console logs for the exact error
- Verify Firestore is initialized properly
- Check if there's a network issue

### 6. Manual User Creation (Workaround)
If you need to test while debugging, create users manually in Firestore:

1. Collection: `users`
2. Document ID: Use the UID from Authentication > Users
3. Fields:
   ```
   displayName: "Test User"
   email: "test@example.com"
   authProviders: ["password"]
   createdAt: (timestamp)
   lastSeen: (timestamp)
   settings: {
     notificationsEnabled: true
     locationSharingEnabled: false
     quietHoursEnabled: false
   }
   ```

## Next Steps
1. Run the app with the added logging
2. Try to sign up with a new email
3. Check the Xcode console for the exact error
4. Share the console output to identify the specific issue