# Location Sharing Setup Instructions

## Required: Add Location Usage Descriptions to Xcode Project

Since iOS 14+, many Info.plist entries are managed through Xcode's project settings. You need to add location usage descriptions for the app to request location permissions.

### Steps to Add Location Permissions:

1. **Open the Homi project in Xcode**
   - Open `Homi.xcodeproj`

2. **Select the Homi target**
   - In the project navigator, click on the "Homi" project (blue icon at top)
   - Select the "Homi" target under TARGETS

3. **Go to the Info tab**
   - Click on the "Info" tab at the top

4. **Add the following custom iOS target properties:**

   Click the "+" button and add these keys:

   **NSLocationWhenInUseUsageDescription**
   - Value: `Homi needs your location to share it with your housemates on the map. You can turn this off anytime.`

   **NSLocationAlwaysAndWhenInUseUsageDescription** (Optional - for background updates)
   - Value: `Homi can share your location in the background so your housemates always know where you are. This is optional.`

### Alternative: Edit Info.plist Directly

If your project has an Info.plist file, add these entries:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Homi needs your location to share it with your housemates on the map. You can turn this off anytime.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Homi can share your location in the background so your housemates always know where you are. This is optional.</string>
```

## Testing Location Sharing

### In the iOS Simulator:

1. **Set a location in the simulator:**
   - In the simulator menu: Features > Location > Custom Location
   - Enter coordinates (e.g., latitude: 37.7749, longitude: -122.4194 for San Francisco)
   - Or use Features > Location > Apple, City Bicycle Ride, etc.

2. **Multiple simulators:**
   - Open multiple simulator instances to test with different users
   - Each can have a different location set
   - Sign in with different test accounts in each

### On a Physical Device:

1. **Enable location services:**
   - Settings > Privacy & Security > Location Services > ON
   - Find Homi app > Select "While Using the App"

2. **Test the permission flow:**
   - Launch the app
   - Go to Location tab
   - Toggle "Share My Location"
   - Grant permission when prompted

3. **Verify location updates:**
   - Walk around to see location updates
   - Check that other housemates can see your location
   - Try turning sharing on/off

## Privacy Features

### User Controls:
- ✅ **Toggle on/off** - Users can disable sharing anytime
- ✅ **While using app** - Only shares when app is open (default)
- ✅ **Visual indicator** - Green dot shows who's actively sharing
- ✅ **Last seen time** - Shows when location was last updated
- ✅ **Settings access** - Easy link to iOS Settings if permission denied

### Privacy Best Practices:
- Location only updates when sharing is enabled
- Updates throttled to every 5 minutes (not real-time tracking)
- Only updates after 100 meters of movement
- Stops sharing when app is closed
- User preference saved locally

## Firestore Structure

Location data is stored per house:

```
/houses/{houseId}/locations/{userId}
  - userId: string
  - userName: string
  - userPhotoURL: string? (optional)
  - latitude: number
  - longitude: number
  - timestamp: timestamp
  - isSharingEnabled: boolean
```

## Security Rules (Add to Firestore)

Add these rules for the locations subcollection:

```javascript
match /houses/{houseId}/locations/{userId} {
  // Members can read all locations in their house
  allow read: if request.auth.uid in get(/databases/$(database)/documents/houses/$(houseId)).data.memberIds;

  // Users can only write their own location
  allow write: if request.auth.uid == userId
    && request.auth.uid in get(/databases/$(database)/documents/houses/$(houseId)).data.memberIds;
}
```

## Troubleshooting

### "Location Permission Required" alert appears
- **Issue:** App doesn't have permission
- **Solution:** Tap "Open Settings" and enable location access for Homi

### Location not updating on map
- **Check:** Is location sharing toggle ON?
- **Check:** Did you grant location permission?
- **Check:** Is location services enabled in iOS Settings?
- **Simulator:** Make sure you set a custom location in simulator

### Can't see other users' locations
- **Check:** Are they sharing their location? (toggle must be ON)
- **Check:** Is their location recent? (updates every 5 min)
- **Check:** Are you both in the same house?

### Location is stale/old
- **Reason:** User hasn't opened app in a while
- **Solution:** Updates only happen when app is in use
- **Note:** Gray "clock" icon indicates older location

## Future Enhancements

Consider adding these features later:

- [ ] Background location updates (requires "Always" permission)
- [ ] Location history/timeline
- [ ] Geofencing (notify when someone arrives/leaves)
- [ ] Location-based reminders
- [ ] Battery-aware updates (reduce frequency on low battery)
- [ ] Location nicknames (Home, Work, Gym, etc.)
- [ ] Travel mode indicator
- [ ] Distance calculations between members
