import SwiftUI
import FirebaseAuth
import OSLog

struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var firestoreService = FirestoreService.shared

    private let logger = Logger(subsystem: "com.homi.app", category: "ContentView")

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Check if user has a house
                if authService.userProfile?.currentHouseId != nil {
                    // Main app view (will be implemented in Phase 2)
                    MainTabView()
                } else {
                    // House setup view (will be implemented in Phase 2)
                    HouseSetupView()
                }
            } else {
                // Authentication flow
                AuthenticationView(viewModel: authViewModel)
            }
        }
        .onAppear {
            // Check authentication state on appear
            if let user = Auth.auth().currentUser {
                Task {
                    await fetchUserProfile(userId: user.uid)
                }
            }
        }
    }

    private func fetchUserProfile(userId: String) async {
        do {
            if let userProfile = try await firestoreService.getUser(id: userId) {
                await MainActor.run {
                    authService.userProfile = userProfile
                }
            }
        } catch {
            logger.error("Error fetching user profile: \(error.localizedDescription)")
        }
    }
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationView {
            Group {
                switch viewModel.currentAuthStep {
                case .welcome:
                    WelcomeView(viewModel: viewModel)

                case .authOptions:
                    AuthOptionsView(viewModel: viewModel)

                case .phoneEntry, .phoneVerification:
                    PhoneAuthView(viewModel: viewModel)

                case .emailSignUp, .emailSignIn:
                    EmailSignUpView(viewModel: viewModel)

                case .profileSetup:
                    ProfileSetupView(viewModel: viewModel)

                case .complete:
                    // This will trigger a re-render and show the main app
                    EmptyView()
                        .onAppear {
                            viewModel.reset()
                        }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Placeholder Views (Will be implemented in Phase 2)

struct MainTabView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var firestoreService = FirestoreService.shared
    @StateObject private var messagingService = MessagingService.shared
    @State private var selectedTab = 0

    private var unreadMessagesCount: Int {
        guard let userId = authService.user?.uid else { return 0 }
        return messagingService.messages.filter { !$0.readBy.contains(userId) }.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            MessagesView(selectedTab: $selectedTab)
                .environmentObject(firestoreService)
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
                .badge(unreadMessagesCount > 0 ? "\(unreadMessagesCount)" : nil)
                .tag(1)

            ExpensesView()
                .tabItem {
                    Label("Bills", systemImage: "dollarsign.circle")
                }
                .tag(2)

            LocationView()
                .tabItem {
                    Label("Location", systemImage: "location")
                }
                .tag(3)

            ChoresView()
                .tabItem {
                    Label("Chores", systemImage: "checklist")
                }
                .tag(4)
        }
        .accentColor(Constants.Colors.primary)
        .onDisappear {
            // Cleanup all listeners when leaving main tab view
            cleanupServices()
        }
    }

    private func cleanupServices() {
        ExpenseService.shared.stopListening()
        ChoreService.shared.stopListening()
        LocationService.shared.stopListening()
    }
}

// Placeholder view for features
struct PlaceholderView: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Constants.Spacing.large) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(color)

            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Coming in Phase 3")
                .font(.title3)
                .foregroundColor(Constants.Colors.textSecondary)

            Text("This feature will be implemented in the next phase of development")
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Spacing.xLarge)
        }
        .padding()
    }
}

struct HouseSetupView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var houseViewModel = HouseViewModel()

    var body: some View {
        NavigationView {
            Group {
                switch houseViewModel.currentStep {
                case .createOrJoin:
                    CreateOrJoinView(viewModel: houseViewModel)

                case .createHouse:
                    CreateHouseView(viewModel: houseViewModel)

                case .joinHouse:
                    JoinHouseView(viewModel: houseViewModel)

                case .setupComplete:
                    HouseSetupCompleteView(viewModel: houseViewModel)
                        .onAppear {
                            // Refresh user profile to get the new house ID
                            if let userId = authService.user?.uid {
                                Task {
                                    if let userProfile = try? await FirestoreService.shared.getUser(id: userId) {
                                        await MainActor.run {
                                            authService.userProfile = userProfile
                                        }
                                    }
                                }
                            }
                        }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
