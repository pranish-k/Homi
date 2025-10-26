import SwiftUI
import MapKit

// MARK: - Location View

struct LocationView: View {
    @StateObject private var viewModel = LocationViewModel()
    @StateObject private var authService = AuthService.shared
    @State private var memberListOffset: CGFloat = 0
    @State private var isCollapsed = false

    // Height constraints
    private let minHeight: CGFloat = 120
    private var maxHeight: CGFloat {
        UIScreen.main.bounds.height * 0.4
    }
    private var collapsedHeight: CGFloat = 60

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Map view
                MapView(viewModel: viewModel)
                    .ignoresSafeArea(edges: .top)

                // Swipeable member list card
                VStack(spacing: 0) {
                    // Drag handle
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)

                    if !isCollapsed {
                        VStack(spacing: Constants.Spacing.medium) {
                            // Sharing toggle
                            LocationSharingToggle(
                                isEnabled: $viewModel.isLocationSharingEnabled,
                                onToggle: { viewModel.toggleLocationSharing() }
                            )

                            // Member locations list
                            MemberLocationsList(viewModel: viewModel)
                        }
                        .padding()
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: isCollapsed ? collapsedHeight : maxHeight)
                .background(
                    RoundedRectangle(cornerRadius: isCollapsed ? 0 : 20)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                )
                .offset(y: memberListOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.height
                            if isCollapsed {
                                // When collapsed, only allow dragging down
                                memberListOffset = max(0, translation)
                            } else {
                                // When expanded, allow both directions
                                memberListOffset = translation
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                let translation = value.translation.height
                                let velocity = value.predictedEndTranslation.height

                                // Determine if should collapse or expand
                                if abs(velocity) > 100 {
                                    // Fast swipe
                                    isCollapsed = velocity > 0
                                } else if abs(translation) > 50 {
                                    // Slow drag threshold
                                    isCollapsed = translation > 0
                                }

                                memberListOffset = 0
                            }
                        }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Location")
                        .font(Constants.Typography.title2)
                }
            }
            .onAppear {
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
            .alert("Location Permission Required", isPresented: $viewModel.showPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    viewModel.openSettings()
                }
            } message: {
                Text("Please enable location access in Settings to share your location with housemates.")
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

// MARK: - Map View

struct MapView: View {
    @ObservedObject var viewModel: LocationViewModel

    var body: some View {
        Map(position: .constant(.region(viewModel.mapRegion))) {
            if viewModel.isLocationSharingEnabled {
                UserAnnotation()
            }

            ForEach(viewModel.activeSharingUsers()) { location in
                Annotation(
                    location.userName,
                    coordinate: location.coordinate
                ) {
                    LocationPin(location: location, isCurrentUser: viewModel.isCurrentUser(location))
                        .onTapGesture {
                            viewModel.centerOnUser(location.userId)
                        }
                }
            }
        }
    }
}

// MARK: - Location Pin

struct LocationPin: View {
    let location: UserLocation
    let isCurrentUser: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Pin icon
            ZStack {
                Circle()
                    .fill(isCurrentUser ? Constants.Colors.primary : Constants.Colors.success)
                    .frame(width: 40, height: 40)
                    .shadow(radius: 3)

                if let photoURL = location.userPhotoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                }
            }

            // Name label
            Text(isCurrentUser ? "You" : location.userName.components(separatedBy: " ").first ?? location.userName)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(isCurrentUser ? Constants.Colors.primary : Constants.Colors.success)
                )
                .shadow(radius: 2)
        }
    }
}

// MARK: - Location Sharing Toggle

struct LocationSharingToggle: View {
    @Binding var isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HomiCard(shadowStyle: .subtle) {
            HStack {
                Image(systemName: isEnabled ? "location.fill" : "location.slash.fill")
                    .foregroundColor(isEnabled ? Constants.Colors.success : Constants.Colors.textSecondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Share My Location")
                        .font(Constants.Typography.headline)

                    Text(isEnabled ? "Your location is visible to housemates" : "Your location is hidden")
                        .font(Constants.Typography.caption1)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
            }
            .padding(Constants.Spacing.cardPadding)
        }
    }
}

// MARK: - Members Locations List

struct MemberLocationsList: View {
    @ObservedObject var viewModel: LocationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
            Text("Housemates")
                .font(.headline)
                .foregroundColor(Constants.Colors.textSecondary)

            if viewModel.activeSharingUsers().isEmpty {
                EmptyLocationState()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Constants.Spacing.medium) {
                        ForEach(viewModel.activeSharingUsers()) { location in
                            MemberLocationCard(
                                location: location,
                                isCurrentUser: viewModel.isCurrentUser(location),
                                onTap: {
                                    viewModel.centerOnUser(location.userId)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

struct EmptyLocationState: View {
    var body: some View {
        HomiEmptyState(
            icon: "location.slash.circle",
            title: "No one is sharing their location",
            message: "Turn on location sharing to let your housemates know where you are"
        )
        .padding()
    }
}

// MARK: - Preview

#Preview {
    LocationView()
}
