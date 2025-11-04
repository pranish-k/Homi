# Firestore Indexes Setup

This document contains the Firestore indexes needed for the Homi app to work without performance issues.

## Required Indexes

### 1. Nudges Collection - Query by Recipient and Timestamp (REQUIRED - Missing!)

**Collection:** `nudges`

**Fields to index:**
- `toUserId` (Ascending)
- `timestamp` (Descending)
- `__name__` (Descending)

**Quick setup link from logs:**
```
https://console.firebase.google.com/v1/r/project/homi-ios/firestore/indexes?create_composite=Ckdwcm9qZWN0cy9ob21pLWlvcy9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvbnVkZ2VzL2luZGV4ZXMvXxABGgwKCHRvVXNlcklkEAEaDQoJdGltZXN0YW1wEAIaDAoIX19uYW1lX18QAg
```

### 2. Nudges Collection - Query by Sender/Recipient/Item

**Collection:** `nudges`

**Fields to index:**
- `fromUserId` (Ascending)
- `toUserId` (Ascending)
- `itemId` (Ascending)
- `timestamp` (Descending)

**Quick setup link from logs:**
```
https://console.firebase.google.com/v1/r/project/homi-ios/firestore/indexes?create_composite=Ckdwcm9qZWN0cy9ob21pLWlvcy9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvbnVkZ2VzL2luZGV4ZXMvXxABGg4KCmZyb21Vc2VySWQQARoKCgZpdGVtSWQQARoMCgh0b1VzZXJJZBABGg0KCXRpbWVzdGFtcBACGgwKCF9fbmFtZV9fEAI
```

## Manual Setup Instructions

If the automatic links don't work, follow these steps:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **homi-ios**
3. Go to **Firestore Database** → **Indexes** tab
4. Click **Create Index**
5. For the Nudges index:
   - Collection ID: `nudges`
   - Add fields in this order:
     1. `fromUserId` - Ascending
     2. `toUserId` - Ascending
     3. `itemId` - Ascending
     4. `timestamp` - Descending
   - Query scope: Collection
6. Click **Create**

The index will take a few minutes to build. Once it's ready, the app performance will significantly improve.

## Why These Indexes Are Needed

The app queries the `nudges` collection to check:
- Who sent the nudge (`fromUserId`)
- Who received it (`toUserId`)
- What item it's about (`itemId`)
- When it was sent (`timestamp`)

Without the composite index, Firestore cannot efficiently run these queries, causing timeouts and UI lag.
