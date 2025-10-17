# Firebase Security Setup Guide

**CRITICAL: Complete these steps before deploying to production!**

## Overview

This guide will help you set up Firebase Security Rules and required indexes for your Homi app. **Without these configurations, your database is vulnerable to unauthorized access.**

---

## Part 1: Firestore Security Rules

### Step 1: Access Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **homi-ios**
3. Navigate to **Firestore Database** in the left sidebar
4. Click on the **Rules** tab

### Step 2: Deploy Security Rules

1. Copy the contents of `firestore.rules` file in your project root
2. Paste it into the Firebase Console Rules editor
3. Click **Publish** button
4. Confirm the deployment

### What These Rules Do:

✅ **User Privacy**
- Users can only read/write their own user data
- No one can access other users' personal information

✅ **House-based Access Control**
- Only house members can access house data
- Only house admins can manage members
- Only house creators can delete houses

✅ **Expense Security**
- Only house members can create/view expenses
- Only expense creator or payer can modify expenses
- Payments are immutable (cannot be edited after creation)
- Amount validation (must be positive, max $1M)

✅ **Chore Permissions**
- Only house members can create/view chores
- Only creator or assignee can update chores
- Only creator can delete chores
- Points validation (0-1000 points)

✅ **Message Controls**
- Only house members can read/send messages
- Users can edit their own messages within 15 minutes
- Users can delete only their own messages
- Message length validation (max 5000 characters)

✅ **Location Privacy**
- Only house members can see locations
- Users can only update their own location
- Users can delete their own location data

✅ **Invite Code Security**
- Authenticated users can read invite codes (to join houses)
- Collision detection prevents duplicate codes
- Only house creators can delete invite codes

### Step 3: Verify Rules Are Active

1. In Firebase Console, check that the **Published** status shows your new rules
2. Test by running your app and checking the **Firestore logs** for any permission denied errors

---

## Part 2: Firestore Indexes

### Why Indexes Are Needed

Your app uses complex queries that require composite indexes. Without them, queries will fail in production.

### Required Indexes

#### Index 1: Chores by Due Date and Completion Status
```
Collection: houses/{houseId}/chores
Fields:
  - isCompleted (Ascending)
  - dueDate (Ascending)
Query Scope: Collection
```

#### Index 2: Chores by Assignee
```
Collection: houses/{houseId}/chores
Fields:
  - assignedTo (Ascending)
  - isCompleted (Ascending)
  - dueDate (Ascending)
Query Scope: Collection
```

#### Index 3: Expenses by Settlement Status
```
Collection: houses/{houseId}/expenses
Fields:
  - isSettled (Ascending)
  - date (Descending)
Query Scope: Collection
```

#### Index 4: Messages by Timestamp
```
Collection: houses/{houseId}/messages
Fields:
  - timestamp (Descending)
Query Scope: Collection
```

### How to Create Indexes

**Option 1: Automatic Creation (Recommended)**
1. Run your app and use all features (create chores, expenses, messages)
2. When a query needs an index, check your Xcode console
3. You'll see a link like: `https://console.firebase.google.com/...`
4. Click the link to automatically create the index
5. Wait 1-2 minutes for the index to build

**Option 2: Manual Creation**
1. Go to Firebase Console > Firestore Database > Indexes tab
2. Click **Create Index**
3. Enter the collection path (e.g., `houses/{houseId}/chores`)
4. Add fields one by one with their sort order
5. Set Query Scope to **Collection**
6. Click **Create**
7. Repeat for all required indexes

### Verify Indexes Are Built

1. Go to Firebase Console > Firestore Database > Indexes
2. Check that all indexes show status: **Enabled** (not "Building")
3. Test your app features to ensure no errors

---

## Part 3: Firebase Configuration Checklist

### Authentication Settings

1. Go to Firebase Console > Authentication > Sign-in method
2. Verify these are enabled:
   - ✅ Email/Password
   - ✅ Phone
   - ✅ Apple Sign-In
3. For Phone Authentication:
   - Add your app to App Check (recommended)
   - Test phone numbers (for development): Add in **Phone numbers for testing** section

### App Check (Highly Recommended for Production)

App Check helps protect your backend resources from abuse.

1. Go to Firebase Console > App Check
2. Click **Get started**
3. Register your app
4. For iOS: Select **App Attest** (for production)
5. For development: Enable **Debug provider**
6. Click **Save**

### Storage Rules (If you add profile photo uploads)

If you plan to allow users to upload profile photos:

1. Go to Firebase Console > Storage > Rules
2. Add these rules:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/profile/{fileName} {
      allow read: if true;  // Profile photos are public
      allow write: if request.auth != null &&
        request.auth.uid == userId &&
        request.resource.size < 5 * 1024 * 1024 &&  // Max 5MB
        request.resource.contentType.matches('image/.*');  // Images only
    }
  }
}
```

---

## Part 4: Rate Limiting & Cost Management

### Set Budget Alerts

1. Go to Firebase Console > Settings (gear icon) > Usage and billing
2. Click **Details & settings** under your current plan
3. Set up budget alerts:
   - Alert at: $10, $50, $100 (adjust based on your budget)
   - Email notifications to your account

### Monitor Usage

Track these metrics weekly:
- **Firestore Reads**: Should be < 50K per day for small user base
- **Firestore Writes**: Should be < 10K per day
- **Storage**: Should be minimal (unless you add file uploads)

### Cost Optimization Tips

1. **Enable Firestore Offline Persistence** (already done in your app ✓)
2. **Implement Pagination** (see MID_BUILD_IMPROVEMENTS.md)
3. **Set TTL on location updates** (already throttled to 5 minutes ✓)
4. **Monitor expensive queries** using Firebase Performance Monitoring

---

## Part 5: Testing Your Security

### Manual Security Tests

Test these scenarios to verify your security rules work:

#### Test 1: Unauthorized Access
1. Open your app without signing in
2. Try to access any data
3. ✅ Should fail with "Permission denied"

#### Test 2: Cross-House Access
1. Create two test accounts
2. Have them join different houses
3. Try to access the other house's data
4. ✅ Should fail with "Permission denied"

#### Test 3: Data Validation
1. Try to create an expense with negative amount
2. ✅ Should fail validation
3. Try to create a chore with 2000 points
4. ✅ Should fail validation (max 1000)

#### Test 4: Invite Code Security
1. Try to join with expired invite code
2. ✅ Should show "Invite code expired"
3. Try to join with invalid code
4. ✅ Should show "Invalid invite code"

### Automated Testing (Optional but Recommended)

Consider setting up Firebase Emulator Suite for local testing:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize emulators
firebase init emulators

# Run emulators
firebase emulators:start
```

---

## Part 6: Production Deployment Checklist

Before submitting to App Store:

### Security
- [ ] Firestore Security Rules deployed and tested
- [ ] All required indexes created and enabled
- [ ] App Check enabled for production
- [ ] Budget alerts configured
- [ ] Security tests passed

### Configuration
- [ ] Production Firebase project (not using dev/test project)
- [ ] GoogleService-Info.plist updated with production config
- [ ] Authentication methods enabled and tested
- [ ] Storage rules added (if using file uploads)

### Monitoring
- [ ] Firebase Analytics enabled
- [ ] Crashlytics integrated (recommended)
- [ ] Performance Monitoring enabled (recommended)
- [ ] Email alerts configured for errors

### Documentation
- [ ] Team has access to Firebase Console
- [ ] Backup of security rules saved in repository
- [ ] Incident response plan documented

---

## Part 7: Troubleshooting

### Common Issues

**Issue**: "Permission denied" errors in production
- **Solution**: Check that security rules are published (not just saved as draft)
- **Solution**: Verify user is authenticated and part of the house

**Issue**: Queries fail with "index required" error
- **Solution**: Click the index creation link in the error message
- **Solution**: Wait 1-2 minutes for index to build before retrying

**Issue**: High Firestore costs
- **Solution**: Implement pagination (see MID_BUILD_IMPROVEMENTS.md)
- **Solution**: Review listener setup (ensure no duplicate listeners)
- **Solution**: Check for infinite loops in your queries

**Issue**: Users can't join houses with invite code
- **Solution**: Check that invite code has 8 characters (you updated from 6 to 8)
- **Solution**: Verify invite hasn't expired (7-day expiration)
- **Solution**: Check Firestore logs for specific error

### Getting Help

- Firebase Documentation: https://firebase.google.com/docs/firestore/security/get-started
- Firebase Support: https://firebase.google.com/support
- Stack Overflow: Tag questions with `firebase` and `firestore`

---

## Summary

**Critical Steps (DO NOT SKIP):**
1. ✅ Deploy Firestore Security Rules
2. ✅ Create all required indexes
3. ✅ Test security rules manually
4. ✅ Set up budget alerts
5. ✅ Enable App Check for production

**Time Required:**
- Security Rules: 5 minutes
- Indexes: 10 minutes (including build time)
- Testing: 15 minutes
- Total: ~30 minutes

**This is the most important 30 minutes of your deployment process. Your app's security depends on it.**

---

Last Updated: October 17, 2025
