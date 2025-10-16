import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var authService = AuthService.shared
    @State private var messageTab = 0
    @Binding var selectedTab: Int

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
                        // Direct Messages (Coming soon)
                        directMessagesPlaceholder
                    }
                } else {
                    // No house - shouldn't happen but handle gracefully
                    noHouseView
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
                }
            }
            .onAppear {
                loadHouseData()
            }
        }
    }

    private var directMessagesPlaceholder: some View {
        VStack(spacing: Constants.Spacing.large) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.primary)

            Text("Direct Messages")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Coming Soon")
                .font(.title3)
                .foregroundColor(Constants.Colors.textSecondary)

            Text("Private messaging between housemates will be available in a future update")
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Spacing.xLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var noHouseView: some View {
        VStack(spacing: Constants.Spacing.large) {
            Image(systemName: "house.slash")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.textSecondary)

            Text("No House Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You need to be part of a house to use messaging")
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Spacing.xLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                print("Error loading house: \(error)")
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
