# Firebase Authentication Setup Guide

## Current Issues and Solutions

### 1. Apple Sign-In Error (Error 1000)
**Issue**: "The operation couldn't be completed (com.apple.AuthenticationServices.AuthorizationError error 1000.)"

**Solution**:
1. In Xcode, select your project target
2. Go to "Signing & Capabilities"
3. Add "Sign in with Apple" capability if not already added
4. Make sure your Bundle ID matches what's configured in Firebase Console
5. For simulator testing, go to Settings > Sign in to your Simulator > Sign in with your Apple ID

### 2. Phone Authentication Issues
**Issue**: Fatal error with PhoneAuthProvider

**Solutions**:
1. **Enable Phone Auth in Firebase Console**:
   - Go to Firebase Console > Authentication > Sign-in method
   - Enable Phone authentication

2. **Add URL Schemes** (Required for phone auth):
   - In Xcode, select your project
   - Go to Info tab
   - Add URL Types
   - Add your REVERSED_CLIENT_ID from GoogleService-Info.plist as a URL scheme

3. **For Testing on Simulator**:
   - Phone auth doesn't work on iOS simulator with real phone numbers
   - Use test phone numbers in Firebase Console:
     - Go to Authentication > Sign-in method > Phone
     - Add test phone numbers like: +1 555-123-4567 with code: 123456

### 3. Email Authentication Internal Error
**Issue**: "An internal error has occurred"

**Solutions**:
1. **Enable Email/Password in Firebase**:
   - Go to Firebase Console > Authentication > Sign-in method
   - Enable Email/Password authentication

2. **Check Firebase Configuration**:
   - Ensure GoogleService-Info.plist is properly added to your project
   - Verify the bundle ID matches

### 4. Google Sign-In Setup
Google Sign-In requires additional setup:

1. **Add Google Sign-In SDK**:
   ```swift
   // In Package Dependencies, add:
   // https://github.com/google/GoogleSignIn-iOS
   ```

2. **Configure URL Schemes**:
   - Add REVERSED_CLIENT_ID from GoogleService-Info.plist as URL scheme
   - Add your bundle ID as another URL scheme

3. **Update Info.plist**:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <!-- REVERSED_CLIENT_ID from GoogleService-Info.plist -->
               <string>com.googleusercontent.apps.YOUR_ID</string>
           </array>
       </dict>
   </array>
   ```

## Required Info.plist Entries

Add these to your Info.plist:

```xml
<!-- For Phone Authentication -->
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>

<!-- URL Types for OAuth -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Get this from GoogleService-Info.plist REVERSED_CLIENT_ID -->
            <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>

<!-- For Sign in with Apple on iOS 13+ -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>https</string>
</array>
```

## Testing Authentication

### Simulator Testing:
1. **Apple Sign-In**: Must be signed into iCloud on simulator
2. **Phone Auth**: Use test numbers configured in Firebase Console
3. **Email**: Works normally
4. **Google**: Requires additional SDK setup

### Test Credentials for Development:
- **Phone**: +1 555-123-4567, Code: 123456 (add in Firebase Console)
- **Email**: test@example.com, Password: Test1234!

## Verifying Setup

Run this checklist:
- [ ] GoogleService-Info.plist is in the project
- [ ] Bundle ID matches Firebase configuration
- [ ] Authentication methods are enabled in Firebase Console
- [ ] URL schemes are configured in Info.plist
- [ ] Sign in with Apple capability is added (if using Apple Sign-In)
- [ ] Test phone numbers are added (for simulator testing)

## Common Errors and Fixes

1. **"No Firebase App"**: Make sure `FirebaseApp.configure()` is called in AppDelegate
2. **"Invalid Bundle ID"**: Check bundle ID matches Firebase project
3. **"Network Error"**: Check internet connection and Firebase project settings
4. **"Invalid Credentials"**: Verify authentication method is enabled in Firebase Console