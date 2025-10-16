import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var authService = AuthService.shared
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let house = firestoreService.currentHouse,
                   let houseId = authService.userProfile?.currentHouseId {
                    // Tab selector
                    Picker("Message Type", selection: $selectedTab) {
                        Text("House Chat").tag(0)
                        Text("Direct Messages").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, Constants.Spacing.medium)
                    .padding(.vertical, Constants.Spacing.small)

                    // Content based on selected tab
                    if selectedTab == 0 {
                        // House Group Chat
                        GroupChatView(houseId: houseId, houseName: house.name)
                            .navigationBarHidden(true)
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
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            loadHouseData()
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
        MessagesView()
            .environmentObject(FirestoreService.shared)
    }
}
