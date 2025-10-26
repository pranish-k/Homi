import SwiftUI
import OSLog

struct MessagesView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var authService = AuthService.shared
    @State private var messageTab = 0
    @Binding var selectedTab: Int

    private let logger = Logger(subsystem: "com.homi.app", category: "MessagesView")

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let house = firestoreService.currentHouse,
                   let houseId = authService.userProfile?.currentHouseId {
                    // Tab selector
                    Picker("Message Type", selection: $messageTab) {
                        Text("House Chat").tag(0)
                        Text("Direct Messages").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, Constants.Spacing.medium)
                    .padding(.vertical, Constants.Spacing.small)

                    // Content based on selected tab
                    if messageTab == 0 {
                        // House Group Chat
                        GroupChatView(houseId: houseId, houseName: house.name)
                    } else {
                        // Direct Messages
                        DirectMessagesListView()
                    }
                } else {
                    // No house - shouldn't happen but handle gracefully
                    noHouseView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: Constants.Spacing.small) {
                        Button(action: {
                            // Dismiss keyboard first
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            // Navigate back to home tab
                            selectedTab = 0
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(Constants.Colors.primary)
                        }

                        Text(messageTab == 0 ? "House Chat" : "Direct Messages")
                            .font(Constants.Typography.title2)
                    }
                }
            }
            .onAppear {
                loadHouseData()
            }
        }
    }

    private var noHouseView: some View {
        HomiEmptyState(
            icon: "house.slash",
            title: "No House Found",
            message: "You need to be part of a house to use messaging"
        )
    }

    private func loadHouseData() {
        guard let houseId = authService.userProfile?.currentHouseId else { return }

        Task {
            do {
                if let house = try await firestoreService.getHouse(id: houseId) {
                    await MainActor.run {
                        firestoreService.currentHouse = house
                    }
                }
            } catch {
                logger.error("Error loading house: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview
struct MessagesView_Previews: PreviewProvider {
    static var previews: some View {
        MessagesView(selectedTab: .constant(1))
            .environmentObject(FirestoreService.shared)
    }
}
