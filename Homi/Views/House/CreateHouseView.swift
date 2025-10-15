import SwiftUI

struct CreateHouseView: View {
    @ObservedObject var viewModel: HouseViewModel
    @FocusState private var focusedField: Field?

    enum Field {
        case name, address
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Constants.Spacing.small) {
                HStack {
                    Button(action: {
                        viewModel.navigateBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(Constants.Colors.textPrimary)
                    }

                    Spacer()
                }

                Text("Create Your House")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Constants.Spacing.medium)

                Text("Give your house a name and optional address")
                    .font(.body)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Constants.Spacing.large)
            .padding(.top, Constants.Spacing.medium)

            ScrollView {
                VStack(spacing: Constants.Spacing.xLarge) {
                    // House Icon
                    Image(systemName: "house.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.top, Constants.Spacing.xLarge)

                    VStack(spacing: Constants.Spacing.large) {
                        // House Name Field
                        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                            Text("House Name")
                                .font(.caption)
                                .foregroundColor(Constants.Colors.textSecondary)

                            TextField("e.g., The Cozy Cottage", text: $viewModel.houseName)
                                .textContentType(.organizationName)
                                .autocapitalization(.words)
                                .focused($focusedField, equals: .name)
                                .padding(.horizontal, Constants.Spacing.medium)
                                .frame(height: 56)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(Constants.CornerRadius.small)

                            Text("This is what your housemates will see")
                                .font(.caption2)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }

                        // House Address Field (Optional)
                        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                            HStack {
                                Text("Address")
                                    .font(.caption)
                                    .foregroundColor(Constants.Colors.textSecondary)

                                Text("(Optional)")
                                    .font(.caption)
                                    .foregroundColor(Constants.Colors.textSecondary.opacity(0.6))
                            }

                            TextField("e.g., 123 Main St, City", text: $viewModel.houseAddress)
                                .textContentType(.fullStreetAddress)
                                .autocapitalization(.words)
                                .focused($focusedField, equals: .address)
                                .padding(.horizontal, Constants.Spacing.medium)
                                .frame(height: 56)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(Constants.CornerRadius.small)

                            Text("Helps housemates remember the location")
                                .font(.caption2)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }

                    // Create Button
                    Button(action: {
                        Task {
                            await viewModel.createHouse()
                        }
                    }) {
                        Text("Create House")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Constants.Colors.primary)
                            .cornerRadius(Constants.CornerRadius.medium)
                    }
                    .disabled(viewModel.houseName.isEmpty)
                    .opacity(viewModel.houseName.isEmpty ? 0.6 : 1)

                    // Info Box
                    HStack(spacing: Constants.Spacing.small) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.primary)

                        VStack(alignment: .leading, spacing: Constants.Spacing.xSmall) {
                            Text("What happens next?")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("You'll get an invite code to share with your housemates so they can join your house.")
                                .font(.caption2)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }
                    .padding(Constants.Spacing.medium)
                    .background(Constants.Colors.primary.opacity(0.1))
                    .cornerRadius(Constants.CornerRadius.small)
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
            focusedField = .name
        }
    }
}