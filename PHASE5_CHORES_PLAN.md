# Phase 5: Chores Management - Implementation Plan

## 🎯 Overview
Build a comprehensive chore management system that allows housemates to create, assign, track, and complete household tasks. Features include recurring chores, rotation systems, and completion tracking.

---

## 📋 Features to Implement

### Core Features:
1. ✅ Create chores with title, description, assignee
2. ✅ Set due dates and frequencies (once, daily, weekly, monthly)
3. ✅ Assign to specific housemate or rotation
4. ✅ Mark chores as complete
5. ✅ View upcoming chores in list or calendar view
6. ✅ Filter chores by assignee
7. ✅ Automatic recurring chore creation
8. ✅ Completion history and stats
9. ✅ Chore categories with icons

### Optional Enhancements:
- Points/gamification system
- Photo proof of completion
- Push notifications/reminders
- Chore templates
- Time estimates

---

## 🗂️ Data Models

### Chore Model
```swift
struct Chore: Identifiable, Codable {
    let id: String
    let houseId: String
    let title: String
    let description: String?
    let assignedTo: String
    let assignedToName: String
    let createdBy: String
    let createdAt: Date
    let dueDate: Date
    let frequency: ChoreFrequency
    let category: ChoreCategory
    let isCompleted: Bool
    let completedAt: Date?
    let completedBy: String?
    let completedByName: String?
    let points: Int
    let rotationEnabled: Bool
    let rotationOrder: [String]? // Array of user IDs
}

enum ChoreFrequency: String, Codable, CaseIterable {
    case once = "One Time"
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Every 2 Weeks"
    case monthly = "Monthly"
}

enum ChoreCategory: String, Codable, CaseIterable {
    case cleaning = "Cleaning"
    case kitchen = "Kitchen"
    case bathroom = "Bathroom"
    case trash = "Trash & Recycling"
    case outdoor = "Outdoor"
    case pets = "Pets"
    case laundry = "Laundry"
    case other = "Other"

    var icon: String {
        switch self {
        case .cleaning: return "sparkles"
        case .kitchen: return "fork.knife"
        case .bathroom: return "shower"
        case .trash: return "trash"
        case .outdoor: return "leaf"
        case .pets: return "pawprint"
        case .laundry: return "tshirt"
        case .other: return "square.grid.2x2"
        }
    }

    var color: Color // Different color per category
}
```

---

## 🔧 Services to Create

### ChoreService.swift
```swift
class ChoreService {
    // CRUD Operations
    - createChore(chore: Chore)
    - updateChore(chore: Chore)
    - deleteChore(houseId: String, choreId: String)

    // Query Operations
    - getChores(houseId: String) -> [Chore]
    - getUpcomingChores(houseId: String, days: Int) -> [Chore]
    - getChoresByAssignee(houseId: String, userId: String) -> [Chore]
    - getOverdueChores(houseId: String) -> [Chore]

    // Real-time Listeners
    - startListeningToChores(houseId: String)
    - stopListening()

    // Completion
    - markChoreComplete(houseId: String, choreId: String, userId: String)
    - markChoreIncomplete(houseId: String, choreId: String)

    // Recurring Logic
    - createNextOccurrence(chore: Chore)
    - rotateChoreAssignment(chore: Chore) -> Chore

    // Stats
    - getCompletionRate(houseId: String, userId: String) -> Double
    - getChoresCompletedCount(houseId: String, userId: String) -> Int
}
```

---

## 🎨 Views to Build

### 1. ChoresView.swift (Main Tab)
**Purpose:** Main chores tab with list/calendar toggle

**Layout:**
- Navigation bar with title "Chores" and + button
- Segmented control: "List" | "Calendar"
- Filter picker: "All" | "Mine" | "Unassigned"
- List view showing chore cards
- Empty state for no chores

**Features:**
- Toggle between list and calendar views
- Filter chores by assignee
- Swipe to complete action
- Tap card to see details

---

### 2. AddChoreView.swift (Form)
**Purpose:** Create new chore

**Form Sections:**
1. **Basic Info**
   - Title (text field)
   - Description (text editor, optional)
   - Category picker

2. **Assignment**
   - Assignee picker (select housemate)
   - Enable rotation toggle
   - Rotation order (if enabled)

3. **Scheduling**
   - Due date picker
   - Frequency picker (once, daily, weekly, etc.)
   - Points (optional, stepper)

**Actions:**
- Cancel button
- Save button (with validation)

---

### 3. ChoreCardView.swift (Reusable Component)
**Purpose:** Display single chore in list

**Layout:**
```
[Category Icon] [Title]                    [Due: Today]
                [Assigned to: John]        [Checkmark]
                [Daily • Cleaning]
```

**Elements:**
- Category icon with color
- Title (bold)
- Assigned to name
- Due date with color coding:
  - Red: Overdue
  - Orange: Due today
  - Yellow: Due tomorrow
  - Gray: Future
- Frequency badge
- Completion checkbox
- Optional: Points display

**Actions:**
- Tap: Show detail
- Swipe left: Complete
- Swipe right: Delete (if creator)
- Long press: Context menu (edit, delete, reassign)

---

### 4. ChoreDetailView.swift
**Purpose:** View and edit chore details

**Layout:**
- Category icon header
- Title and description
- Assignment info
- Due date and frequency
- Completion status
- If completed: who and when
- History (if recurring)

**Actions:**
- Edit button
- Delete button (if creator)
- Mark complete/incomplete toggle
- Reassign button

---

### 5. ChoreCalendarView.swift
**Purpose:** Calendar view of chores

**Layout:**
- Month calendar with dots on dates with chores
- Selected date shows list of chores for that day
- Color-coded dots by category
- Swipe between months

---

### 6. ChoreStatsView.swift (Optional)
**Purpose:** Show completion statistics

**Layout:**
- Completion rate per person (bar chart)
- Total chores completed this week/month
- Streak tracking
- Points leaderboard (if using points)

---

## 🎯 User Flows

### Create Chore Flow:
1. Tap + in ChoresView
2. Fill out form (title, category, assignee, etc.)
3. Tap Save
4. Chore appears in list
5. If recurring, shows "Next: [date]"

### Complete Chore Flow:
1. See chore in list
2. Swipe left → "Complete" button
3. Tap Complete
4. Chore marked done with green checkmark
5. If recurring, next occurrence auto-created
6. If rotation enabled, assigned to next person

### Rotation Flow:
1. Create chore with rotation enabled
2. Set rotation order: [Alice, Bob, Charlie]
3. First occurrence assigned to Alice
4. When Alice completes, next occurrence assigned to Bob
5. Continues rotating through the order

---

## 🔥 Firestore Structure

```
/houses/{houseId}/chores/{choreId}
├── id: String
├── houseId: String
├── title: String
├── description: String?
├── assignedTo: String
├── assignedToName: String (denormalized)
├── createdBy: String
├── createdAt: Timestamp
├── dueDate: Timestamp
├── frequency: String
├── category: String
├── isCompleted: Boolean
├── completedAt: Timestamp?
├── completedBy: String?
├── completedByName: String? (denormalized)
├── points: Number
├── rotationEnabled: Boolean
└── rotationOrder: [String]?

// Optional: Completion history for recurring chores
/houses/{houseId}/chores/{choreId}/completions/{completionId}
├── completedAt: Timestamp
├── completedBy: String
├── completedByName: String
└── notes: String?
```

---

## 🎨 UI/UX Considerations

### Color Coding:
- **Overdue**: Red background/text
- **Due Today**: Orange
- **Due Tomorrow**: Yellow
- **Future**: Gray
- **Completed**: Green checkmark

### Badges:
- Frequency badge: "Daily", "Weekly", etc.
- Points badge: "10 pts" (if using points)
- Rotation badge: "🔄 Rotating"

### Icons:
- Category icons from SF Symbols
- Completion: `checkmark.circle.fill`
- Overdue: `exclamationmark.triangle.fill`
- Calendar: `calendar`
- Person: `person.circle`

### Animations:
- Check animation when completing
- Confetti for streaks (optional)
- Slide animations for list updates

---

## 🚀 Implementation Steps

### Step 1: Models & Services (Backend)
1. Create Chore.swift model
2. Create ChoreService.swift
3. Add chores collection constant
4. Implement CRUD operations
5. Add real-time listeners

### Step 2: Core Views (UI)
1. Create ChoreCardView (reusable)
2. Create ChoresView (main tab)
3. Create AddChoreView (form)
4. Replace placeholder in ContentView

### Step 3: Advanced Features
1. Create ChoreDetailView
2. Implement completion logic
3. Add recurring chore creation
4. Implement rotation system

### Step 4: Calendar & Stats (Optional)
1. Create ChoreCalendarView
2. Create ChoreStatsView
3. Add filtering options

### Step 5: Polish
1. Add animations
2. Add haptic feedback
3. Empty states
4. Error handling
5. Form validation

---

## ✅ Success Criteria

Phase 5 will be considered complete when:
- ✅ Users can create chores with all fields
- ✅ Chores display in a list with proper formatting
- ✅ Users can mark chores as complete
- ✅ Recurring chores auto-create next occurrence
- ✅ Rotation system works correctly
- ✅ Real-time updates work
- ✅ Empty states display properly
- ✅ Form validation works
- ✅ Delete chores works
- ✅ Build succeeds with no warnings

---

## 📝 Notes

- Focus on core features first (create, assign, complete)
- Calendar view can be added later if time permits
- Points system is optional, can skip for MVP
- Photo proof is nice-to-have, not required
- Notifications require separate setup, can be Phase 6+

---

Ready to start building! 🎉
