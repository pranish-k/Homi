import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Constants.Spacing.small) {
                Text("Complete Your Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Constants.Spacing.xLarge)

                Text("Add a photo and name to help housemates recognize you")
                    .font(.body)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Constants.Spacing.large)

            ScrollView {
                VStack(spacing: Constants.Spacing.xLarge) {
                    // Profile Photo
                    VStack(spacing: Constants.Spacing.medium) {
                        PhotosPicker(selection: $selectedItem,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            ZStack {
                                if let imageData = selectedImageData,
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color(.separator), lineWidth: 1)
                                        )
                                } else {
                                    Circle()
                                        .fill(Color(.secondarySystemBackground))
                                        .frame(width: 120, height: 120)
                                        .overlay {
                                            VStack(spacing: Constants.Spacing.xSmall) {
                                                Image(systemName: "camera.fill")
                                                    .font(.title2)
                                                    .foregroundColor(Constants.Colors.textSecondary)
                                                Text("Add Photo")
                                                    .font(.caption)
                                                    .foregroundColor(Constants.Colors.textSecondary)
                                            }
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                                .foregroundColor(Color(.separator))
                                        )
                                }
                            }
                        }
                        .onChange(of: selectedItem) { oldItem, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                    if let uiImage = UIImage(data: data) {
                                        viewModel.profileImage = uiImage
                                    }
                                }
                            }
                        }

                        Text("Optional")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.top, Constants.Spacing.large)

                    // Display Name
                    VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                        Text("Display Name")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)

                        TextField("Enter your name", text: $viewModel.displayName)
                            .textContentType(.name)
                            .autocapitalization(.words)
                            .focused($isNameFocused)
                            .padding(.horizontal, Constants.Spacing.medium)
                            .frame(height: 56)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(Constants.CornerRadius.small)

                        Text("This is how you'll appear to your housemates")
                            .font(.caption2)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }

                    // Complete Setup Button
                    Button(action: {
                        Task {
                            await viewModel.completeProfileSetup()
                        }
                    }) {
                        Text("Complete Setup")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Constants.Colors.primary)
                            .cornerRadius(Constants.CornerRadius.medium)
                    }
                    .disabled(viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)

                    // Skip for now (if photo is optional)
                    if selectedImageData == nil {
                        Button(action: {
                            Task {
                                await viewModel.completeProfileSetup()
                            }
                        }) {
                            Text("Skip photo for now")
                                .font(.subheadline)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                        .disabled(viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, Constants.Spacing.large)
                .padding(.vertical, Constants.Spacing.xLarge)
            }
        }
        .background(Color(.systemBackground))
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
            }
        }
        .onAppear {
            // Pre-fill with existing name if available
            if let currentName = AuthService.shared.userProfile?.displayName,
               !currentName.isEmpty {
                viewModel.displayName = currentName
            } else if !viewModel.fullName.isEmpty {
                viewModel.displayName = viewModel.fullName
            }

            isNameFocused = viewModel.displayName.isEmpty
        }
    }
}