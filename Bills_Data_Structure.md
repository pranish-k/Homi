# Bills (Expenses) Data Structure - Detailed Documentation

## Overview
The Homi app's billing system is designed around a split-bill model where one person pays for an expense and the cost is split among multiple housemates. The system tracks who paid, who owes, and automatically calculates balances between users.

---

## Core Data Models

### 1. **Expense Model**
The primary model representing a bill/expense in the system.

**File**: [Expense.swift](Homi/Models/Expense.swift)

**Structure**:
```swift
struct Expense: Identifiable, Codable {
    let id: String                    // Unique identifier (UUID)
    let houseId: String               // Reference to the house
    let amount: Double                // Total amount of the expense
    let description: String           // What the expense was for
    let category: ExpenseCategory     // Category (rent, groceries, etc.)
    let date: Date                    // When the expense occurred
    let paidBy: String                // User ID of who paid
    let paidByName: String            // Display name of who paid
    let splits: [ExpenseSplit]        // How the expense is divided
    let isSettled: Bool               // True when all splits are paid
    let createdAt: Date               // When expense was created
    let createdBy: String             // User ID of creator
}
```

**Key Features**:
- **Total Amount**: The full bill amount
- **Paid By**: Tracks who initially paid the expense
- **Splits**: Array of how the bill is divided among housemates
- **Settlement Status**: Automatically marked as settled when all splits are paid
- **Category System**: Organizes expenses by type (see ExpenseCategory below)

**Firestore Storage**:
- Collection: `houses/{houseId}/expenses/{expenseId}`
- Automatically synced in real-time via listeners

---

### 2. **ExpenseSplit Model**
Represents each person's portion of an expense.

**Structure**:
```swift
struct ExpenseSplit: Codable, Identifiable {
    let userId: String        // Who owes this split
    let userName: String      // Display name
    let amount: Double        // How much they owe
    var isPaid: Bool          // Payment status
}
```

**How Splits Work**:
1. When an expense is created, it's divided among selected housemates
2. Each person gets a split with their portion
3. The person who paid has their split automatically marked as `isPaid: true`
4. Others have `isPaid: false` until they pay back

**Example**:
```swift
// Grocery bill of $90 split among 3 people
Expense(
    amount: 90.00,
    paidBy: "user1",
    splits: [
        ExpenseSplit(userId: "user1", amount: 30.00, isPaid: true),   // Paid (payer)
        ExpenseSplit(userId: "user2", amount: 30.00, isPaid: false),  // Owes
        ExpenseSplit(userId: "user3", amount: 30.00, isPaid: false)   // Owes
    ]
)
```

---

### 3. **Payment Model**
Tracks when someone pays back their portion.

**Structure**:
```swift
struct Payment: Identifiable, Codable {
    let id: String                    // Unique identifier
    let houseId: String               // House reference
    let fromUserId: String            // Who made the payment
    let fromUserName: String          // Payer's name
    let toUserId: String              // Who received the payment
    let toUserName: String            // Receiver's name
    let amount: Double                // Payment amount
    let expenseIds: [String]          // Related expenses being settled
    let note: String?                 // Optional note
    let timestamp: Date               // When payment was made
}
```

**Payment Flow**:
1. User clicks "Clear Balance" or "Settle Up"
2. Payment record is created
3. Related expense splits are marked as `isPaid: true`
4. If all splits for an expense are paid, expense becomes `isSettled: true`
5. Payment appears in payment history

**Firestore Storage**:
- Collection: `houses/{houseId}/payments/{paymentId}`

---

### 4. **Balance Model**
Calculated summary of money owed between users (not stored in database, computed in real-time).

**Structure**:
```swift
struct Balance: Identifiable {
    let userId: String              // Other user's ID
    let userName: String            // Other user's name
    var owedToYou: Double          // Money they owe you
    var youOwe: Double             // Money you owe them

    var netBalance: Double {
        return owedToYou - youOwe   // Net result
    }
}
```

**Balance Calculation Logic**:
```swift
// For each house member (excluding current user):
// 1. Check all unsettled expenses where current user paid
//    → Add their unpaid splits to owedToYou
// 2. Check all unsettled expenses where current user has unpaid split
//    → Add current user's split to youOwe
// 3. Subtract any recorded payments
// 4. Calculate netBalance = owedToYou - youOwe
```

**Net Balance Interpretation**:
- **Positive**: They owe you money
- **Negative**: You owe them money
- **Zero**: Settled up

---

### 5. **ExpenseCategory Enum**
Categorizes expenses for better organization.

**Available Categories**:
```swift
enum ExpenseCategory: String, CaseIterable {
    case rent = "Rent"                    // 🏠 House rent
    case utilities = "Utilities"          // ⚡ Electric, water, gas
    case groceries = "Groceries"          // 🛒 Food shopping
    case supplies = "Supplies"            // 🛍️ Household items
    case internet = "Internet"            // 📡 Internet/cable
    case cleaning = "Cleaning"            // ✨ Cleaning supplies/service
    case maintenance = "Maintenance"      // 🔧 Repairs
    case other = "Other"                  // ⭕ Everything else
}
```

Each category has:
- Icon (SF Symbol)
- Color coding for visual distinction

---

## How the System Works

### Creating an Expense

**Process**:
1. User creates expense with:
   - Amount (e.g., $100)
   - Description (e.g., "Grocery shopping")
   - Category (e.g., Groceries)
   - Date
   - Who paid (defaults to current user)
   - Who to split with (select housemates)

2. System automatically:
   - Divides amount equally among selected people
   - Creates ExpenseSplit for each person
   - Marks payer's split as paid
   - Saves to Firestore

**Example Flow**:
```
User adds $120 grocery bill, splits with 3 people:
→ Creates Expense with amount: $120
→ Generates 3 splits of $40 each
→ User's split: isPaid = true
→ Others' splits: isPaid = false
```

---

### Balance Calculation Algorithm

**Location**: [ExpenseService.swift:247-293](Homi/Services/ExpenseService.swift#L247-L293)

**Steps**:
1. **Initialize**: Create Balance object for each housemate
2. **Process Expenses**:
   - For each unsettled expense:
     - If current user paid → add unpaid splits to `owedToYou`
     - If current user has unpaid split → add to `youOwe`
3. **Subtract Payments**:
   - Reduce balances by recorded payment amounts
4. **Filter**: Remove zero balances
5. **Return**: List of non-zero balances

**Code Reference**:
```swift
func calculateBalances(currentUserId: String, houseMembers: [HouseMember]) -> [Balance] {
    var balanceDict: [String: Balance] = [:]

    // Initialize for all members
    for member in houseMembers where member.userId != currentUserId {
        balanceDict[member.userId] = Balance(
            userId: member.userId,
            userName: member.displayName,
            owedToYou: 0,
            youOwe: 0
        )
    }

    // Process unsettled expenses
    let unsettledExpenses = expenses.filter { !$0.isSettled }

    for expense in unsettledExpenses {
        if expense.paidBy == currentUserId {
            // Add unpaid splits to owedToYou
            expense.splits.forEach { split in
                guard split.userId != currentUserId && !split.isPaid else { return }
                balanceDict[split.userId]?.owedToYou += split.amount
            }
        } else if let currentUserSplit = expense.splits.first(where: {
            $0.userId == currentUserId && !$0.isPaid
        }) {
            // Add to youOwe
            balanceDict[expense.paidBy]?.youOwe += currentUserSplit.amount
        }
    }

    // Subtract payments
    for payment in payments {
        if payment.toUserId == currentUserId {
            balanceDict[payment.fromUserId]?.owedToYou -= payment.amount
        } else if payment.fromUserId == currentUserId {
            balanceDict[payment.toUserId]?.youOwe -= payment.amount
        }
    }

    // Return non-zero balances
    return balanceDict.values.filter { $0.netBalance != 0 }
}
```

---

### Payment/Settlement Process

**When User Clicks "Clear Balance"**:

1. **Opens Settlement Sheet**: Shows amount owed/owing
2. **User Confirms**: Can add optional note
3. **Payment Created**:
   ```swift
   Payment(
       houseId: houseId,
       fromUserId: currentUser,      // Who's paying
       toUserId: otherUser,           // Who receives
       amount: balanceAmount,
       expenseIds: relatedExpenses,   // Which bills this settles
       timestamp: Date()
   )
   ```

4. **Updates Expenses**:
   - Marks relevant splits as `isPaid: true`
   - If all splits paid → sets `isSettled: true`

5. **Saves to Firestore**: Using batch write for atomicity

**Code Reference**: [ExpenseService.swift:165-206](Homi/Services/ExpenseService.swift#L165-L206)

---

### Real-time Synchronization

**Listeners**:
The app uses Firestore real-time listeners for instant updates.

```swift
// Expenses listener
func startListeningToExpenses(houseId: String) {
    expensesListener = db.collection("houses/\(houseId)/expenses")
        .order(by: "date", descending: true)
        .addSnapshotListener { snapshot, error in
            // Update expenses array
            self.expenses = snapshot.documents.compactMap {
                Expense.fromFirestore($0.data())
            }
        }
}

// Payments listener
func startListeningToPayments(houseId: String) {
    paymentsListener = db.collection("houses/\(houseId)/payments")
        .order(by: "timestamp", descending: true)
        .addSnapshotListener { snapshot, error in
            // Update payments array
            self.payments = snapshot.documents.compactMap {
                Payment.fromFirestore($0.data())
            }
        }
}
```

**Features**:
- Automatic retry with exponential backoff on connection failure
- Updates UI instantly when expenses/payments change
- Handles offline mode gracefully

---

## UI Components

### 1. **ExpensesView**
Main view with two tabs:
- **Balances Tab**: Shows who owes whom
- **Transactions Tab**: Lists all expenses

**File**: [ExpensesView.swift](Homi/Views/Expenses/ExpensesView.swift)

### 2. **BalanceSummaryView**
Displays individual balance cards with:
- User avatar
- Amount owed/owing
- "Clear Balance" button (when they owe you)
- "Settle Up" button (when you owe them)
- "Nudge" button to remind them
- Payment history link

**File**: [BalanceSummaryView.swift](Homi/Views/Expenses/BalanceSummaryView.swift)

### 3. **ExpenseCardView**
Shows individual expense with:
- Amount and description
- Category icon
- Who paid
- Split details
- Payment status

**File**: [ExpenseCardView.swift](Homi/Views/Expenses/ExpenseCardView.swift)

---

## Firestore Database Structure

```
houses/
  {houseId}/
    expenses/
      {expenseId}/
        - id: String
        - houseId: String
        - amount: Double
        - description: String
        - category: String
        - date: Timestamp
        - paidBy: String
        - paidByName: String
        - splits: Array<Map>
          - userId: String
          - userName: String
          - amount: Double
          - isPaid: Boolean
        - isSettled: Boolean
        - createdAt: Timestamp
        - createdBy: String

    payments/
      {paymentId}/
        - id: String
        - houseId: String
        - fromUserId: String
        - fromUserName: String
        - toUserId: String
        - toUserName: String
        - amount: Double
        - expenseIds: Array<String>
        - note: String (optional)
        - timestamp: Timestamp
```

---

## Key Business Logic

### Automatic Settlement Detection
```swift
// When marking a split as paid:
let allPaid = updatedSplits.allSatisfy { $0.isPaid }
if allPaid {
    expense.isSettled = true  // Expense is fully settled
}
```

### Equal Split Calculation
When creating expense, splits are calculated as:
```swift
let splitAmount = totalAmount / numberOfPeople
// Handle rounding: last person gets remainder
splits[last].amount += totalAmount - (splitAmount * numberOfPeople)
```

### Balance Filtering
Only show balances where money is actually owed:
```swift
balances.filter { $0.netBalance != 0 }
```

### Total Calculations
```swift
// Total you owe
func getTotalYouOwe(currentUserId: String) -> Double {
    expenses
        .filter { !$0.isSettled }
        .compactMap { expense in
            expense.splits.first(where: {
                $0.userId == currentUserId && !$0.isPaid
            })?.amount
        }
        .reduce(0, +)
}

// Total owed to you
func getTotalOwedToYou(currentUserId: String) -> Double {
    expenses
        .filter { !$0.isSettled && $0.paidBy == currentUserId }
        .flatMap { expense in
            expense.splits.filter {
                $0.userId != currentUserId && !$0.isPaid
            }
        }
        .map(\.amount)
        .reduce(0, +)
}
```

---

## Example Scenarios

### Scenario 1: Simple Bill Split
**Situation**: Alice pays $60 for groceries, splits with Bob and Charlie.

**Data Created**:
```swift
Expense(
    amount: 60.00,
    description: "Groceries",
    paidBy: "alice",
    splits: [
        ExpenseSplit(userId: "alice", amount: 20.00, isPaid: true),
        ExpenseSplit(userId: "bob", amount: 20.00, isPaid: false),
        ExpenseSplit(userId: "charlie", amount: 20.00, isPaid: false)
    ],
    isSettled: false
)
```

**Balance View (Alice's perspective)**:
- Bob owes you: $20.00
- Charlie owes you: $20.00

**Balance View (Bob's perspective)**:
- You owe Alice: $20.00

---

### Scenario 2: Multiple Expenses
**Situation**:
- Alice pays $60 groceries (split 3 ways)
- Bob pays $90 utilities (split 3 ways)

**Balances (Alice's perspective)**:
```
Bob:
  owedToYou: $20 (from groceries)
  youOwe: $30 (from utilities)
  netBalance: -$10 (you owe Bob $10)

Charlie:
  owedToYou: $20 (from groceries)
  youOwe: $30 (from utilities)
  netBalance: -$10 (you owe Charlie $10)
```

---

### Scenario 3: After Payment
**Continuing Scenario 2**: Alice pays Bob $10.

**Payment Created**:
```swift
Payment(
    fromUserId: "alice",
    toUserId: "bob",
    amount: 10.00,
    expenseIds: ["groceryId", "utilitiesId"]
)
```

**Updated Balance (Alice's perspective)**:
```
Bob:
  owedToYou: $20
  youOwe: $30
  payments: -$10
  netBalance: -$20 → $0 (settled!)

Charlie:
  netBalance: -$10 (still owes)
```

---

## Performance Optimizations

1. **Filtered Queries**: Only process unsettled expenses
2. **Batch Operations**: Use Firestore batch writes for payments
3. **Real-time Updates**: Listeners keep UI in sync without polling
4. **Computed Properties**: Balances calculated on-demand, not stored
5. **Exponential Backoff**: Automatic retry for failed connections

---

## Security Considerations

1. **Firestore Rules**: Should validate:
   - User is member of house
   - Can only modify own splits
   - Cannot delete others' expenses

2. **Data Validation**:
   - Amounts must be positive
   - Splits must add up to total
   - Cannot mark others' splits as paid

3. **Audit Trail**:
   - `createdBy` and `createdAt` track who created expense
   - Payment history is immutable once created

---

## Future Enhancements

Potential improvements to consider:

1. **Recurring Expenses**: Rent, utilities that repeat monthly
2. **Unequal Splits**: Custom amounts per person
3. **Expense Attachments**: Photos of receipts
4. **Budget Tracking**: Set limits per category
5. **Export Reports**: Monthly/yearly expense summaries
6. **Currency Support**: Multi-currency for international houses
7. **Payment Methods**: Integration with Venmo, PayPal, etc.

---

## Summary

The bills system is built on a **split-expense model** where:
- One person pays the full amount
- Bill is divided among selected housemates
- System tracks who owes what
- Balances automatically calculated
- Payments settle balances and update expense status
- Everything syncs in real-time via Firestore

The design emphasizes **simplicity** and **accuracy** - users shouldn't have to think about complex math, the app handles all calculations automatically.
