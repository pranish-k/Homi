import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Payment History View

struct PaymentHistoryView: View {
    @StateObject private var viewModel: PaymentHistoryViewModel
    @Environment(\.dismiss) private var dismiss

    let filterUserId: String?
    let filterUserName: String?

    init(filterUserId: String? = nil, filterUserName: String? = nil) {
        self.filterUserId = filterUserId
        self.filterUserName = filterUserName
        _viewModel = StateObject(wrappedValue: PaymentHistoryViewModel(filterUserId: filterUserId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.payments.isEmpty {
                    loadingView
                } else if viewModel.payments.isEmpty {
                    emptyStateView
                } else {
                    paymentsList
                }
            }
            .navigationTitle(filterUserName != nil ? "Payments with \(filterUserName!)" : "Payment History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadPayments()
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Constants.Spacing.medium) {
            ProgressView()
            Text("Loading payments...")
                .font(Constants.Typography.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        HomiEmptyState(
            icon: "dollarsign.circle",
            title: "No Payments Yet",
            message: "When you settle up with housemates, payment records will appear here"
        )
    }

    // MARK: - Payments List

    private var paymentsList: some View {
        ScrollView {
            LazyVStack(spacing: Constants.Spacing.sectionSpacing, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.groupedPayments.keys.sorted(by: >), id: \.self) { monthYear in
                    Section {
                        VStack(spacing: Constants.Spacing.small) {
                            if let payments = viewModel.groupedPayments[monthYear] {
                                ForEach(payments) { payment in
                                    PaymentTimelineCard(payment: payment)
                                }
                            }
                        }
                        .padding(.horizontal, Constants.Spacing.screenPadding)
                    } header: {
                        MonthHeaderView(monthYear: monthYear)
                    }
                }
            }
            .padding(.vertical, Constants.Spacing.medium)
        }
    }
}

// MARK: - Month Header View

struct MonthHeaderView: View {
    let monthYear: String

    var body: some View {
        HStack {
            Text(monthYear)
                .font(Constants.Typography.headline)
                .foregroundColor(Constants.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Constants.Spacing.screenPadding)
        .padding(.vertical, Constants.Spacing.small)
        .background(Constants.Colors.background)
    }
}

// MARK: - Payment Timeline Card

struct PaymentTimelineCard: View {
    let payment: Payment
    @StateObject private var authService = AuthService.shared

    var isCurrentUserPayer: Bool {
        payment.fromUserId == authService.user?.uid
    }

    var body: some View {
        HomiCard(shadowStyle: .subtle) {
            HStack(spacing: Constants.Spacing.medium) {
                // Timeline indicator
                VStack {
                    Circle()
                        .fill(Constants.Colors.success)
                        .frame(width: 12, height: 12)

                    if !isLast {
                        Rectangle()
                            .fill(Constants.Colors.tertiaryBackground)
                            .frame(width: 2)
                    }
                }
                .frame(width: 12)

                // Payment details
                VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                    // Amount (large, bold)
                    Text(payment.formattedAmount)
                        .font(Constants.Typography.title2)
                        .foregroundColor(isCurrentUserPayer ? Constants.Colors.danger : Constants.Colors.success)

                    // Transaction description
                    HStack(spacing: 4) {
                        Text(isCurrentUserPayer ? "You paid" : payment.fromUserName + " paid")
                            .font(Constants.Typography.body)
                            .foregroundColor(Constants.Colors.textPrimary)

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)

                        Text(isCurrentUserPayer ? payment.toUserName : "you")
                            .font(Constants.Typography.bodyMedium)
                            .foregroundColor(Constants.Colors.textPrimary)
                    }

                    // Date and time
                    Text(payment.relativeDate)
                        .font(Constants.Typography.caption1)
                        .foregroundColor(Constants.Colors.textSecondary)

                    // Note (if exists)
                    if let note = payment.note, !note.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "note.text")
                                .font(.caption2)
                                .foregroundColor(Constants.Colors.textSecondary)

                            Text(note)
                                .font(Constants.Typography.caption1)
                                .foregroundColor(Constants.Colors.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // Status badge
                HomiBadge(
                    "Paid",
                    icon: "checkmark.circle.fill",
                    style: .success,
                    size: .small
                )
            }
            .padding(Constants.Spacing.cardPadding)
        }
    }

    // Helper to determine if this is the last card (for timeline line)
    private var isLast: Bool {
        // This is a simplification - in a real implementation,
        // you'd check if this is the last payment in the section
        false
    }
}

// MARK: - Payment History ViewModel

@MainActor
class PaymentHistoryViewModel: ObservableObject {
    @Published var payments: [Payment] = []
    @Published var groupedPayments: [String: [Payment]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let expenseService = ExpenseService.shared
    private let authService = AuthService.shared
    private let filterUserId: String?

    init(filterUserId: String? = nil) {
        self.filterUserId = filterUserId
    }

    func loadPayments() async {
        guard let houseId = authService.userProfile?.currentHouseId,
              let currentUserId = authService.user?.uid else { return }

        isLoading = true

        do {
            let allPayments = try await expenseService.getPaymentHistory(houseId: houseId)

            // Filter payments if userId is provided
            if let filterUserId = filterUserId {
                payments = allPayments.filter { payment in
                    (payment.fromUserId == currentUserId && payment.toUserId == filterUserId) ||
                    (payment.fromUserId == filterUserId && payment.toUserId == currentUserId)
                }
            } else {
                // Show all payments involving current user
                payments = allPayments.filter { payment in
                    payment.fromUserId == currentUserId || payment.toUserId == currentUserId
                }
            }

            groupPaymentsByMonth()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func groupPaymentsByMonth() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        groupedPayments = Dictionary(grouping: payments) { payment in
            formatter.string(from: payment.timestamp)
        }
    }
}

// MARK: - Payment Extension for Relative Date

extension Payment {
    var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(timestamp) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return "Today at \(timeFormatter.string(from: timestamp))"
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: timestamp, to: now).day {
            if daysAgo < 7 {
                return "\(daysAgo) days ago"
            } else if daysAgo < 30 {
                let weeksAgo = daysAgo / 7
                return "\(weeksAgo) \(weeksAgo == 1 ? "week" : "weeks") ago"
            }
        }

        // Fall back to formatted date
        return formattedDate
    }
}

// MARK: - Preview

#Preview {
    PaymentHistoryView()
}
