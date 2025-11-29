import SwiftUI
import FirebaseAuth
import FirebaseFirestore
// import FirebaseFunctions // Uncomment after adding to Package.swift

struct DataPrivacyView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showDeleteConfirmation = false
    @State private var showExportConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeleting = false
    @State private var isDeletionComplete = false
    @State private var deletionError: String?
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Your Data") {
                    // Export Data
                    Button(action: { showExportConfirmation = true }) {
                        HStack {
                            Label("Export My Data", systemImage: "square.and.arrow.up")
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isExporting)

                    // Download Data Info
                    Text("Export all your Homi data including expenses, payments, messages, and profile information.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Data Management") {
                    // Clear Cache
                    Button(action: clearCache) {
                        Label("Clear Local Cache", systemImage: "trash")
                    }

                    Text("Clears temporarily stored data. Your account data remains safe.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Account Deletion") {
                    // Delete Account
                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        HStack {
                            Label("Delete My Account", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Spacer()
                            if isDeleting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isDeleting)

                    Text("Permanently delete your account and all associated data. This action cannot be undone.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Data & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Export Your Data", isPresented: $showExportConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Export") {
                    Task {
                        await exportUserData()
                    }
                }
            } message: {
                Text("Your data will be prepared and saved to your device as a JSON file.")
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                Button("Cancel", role: .cancel) {
                    deleteConfirmationText = ""
                }
                Button("Delete Permanently", role: .destructive) {
                    if deleteConfirmationText == "DELETE" {
                        Task {
                            await deleteAccount()
                        }
                    }
                }
                .disabled(deleteConfirmationText != "DELETE")
            } message: {
                Text("This will permanently delete your account and all data. Type DELETE to confirm.")
            }
            .alert("Account Deleted", isPresented: $isDeletionComplete) {
                Button("OK") {
                    // Sign out and return to login
                    try? Auth.auth().signOut()
                }
            } message: {
                Text("Your account has been permanently deleted.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Functions

    private func clearCache() {
        // Clear image cache
        URLCache.shared.removeAllCachedResponses()

        // Clear Firestore cache
        Firestore.firestore().clearPersistence { error in
            if let error = error {
                print("Error clearing Firestore cache: \(error)")
            }
        }

        // Clear any app-specific cache
        ExpenseCacheService.shared.invalidateCache()

        HapticManager.success()
    }

    private func exportUserData() async {
        isExporting = true

        do {
            guard let userId = authService.user?.uid,
                  let houseId = authService.userProfile?.currentHouseId else {
                throw NSError(domain: "Export", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }

            let db = Firestore.firestore()
            var exportData: [String: Any] = [:]

            // Collect user profile
            if let profile = authService.userProfile {
                var profileDict: [String: Any] = [
                    "id": profile.id,
                    "displayName": profile.displayName
                ]

                if let email = profile.email {
                    profileDict["email"] = email
                }
                if let phoneNumber = profile.phoneNumber {
                    profileDict["phoneNumber"] = phoneNumber
                }
                if let profilePhotoUrl = profile.profilePhotoUrl {
                    profileDict["profilePhotoUrl"] = profilePhotoUrl
                }
                if let currentHouseId = profile.currentHouseId {
                    profileDict["currentHouseId"] = currentHouseId
                }
                profileDict["createdAt"] = profile.createdAt.ISO8601Format()
                profileDict["lastSeen"] = profile.lastSeen.ISO8601Format()

                exportData["profile"] = profileDict
            }

            // Collect expenses
            let expenses = try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.expenses)
                .whereField("paidBy", isEqualTo: userId)
                .getDocuments()

            exportData["expenses"] = expenses.documents.map { $0.data() }

            // Collect payments
            let paymentsSent = try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.payments)
                .whereField("fromUserId", isEqualTo: userId)
                .getDocuments()

            let paymentsReceived = try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.payments)
                .whereField("toUserId", isEqualTo: userId)
                .getDocuments()

            exportData["paymentsSent"] = paymentsSent.documents.map { $0.data() }
            exportData["paymentsReceived"] = paymentsReceived.documents.map { $0.data() }

            // Create JSON file
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)

            // Save to temporary directory
            let fileName = "homi_data_export_\(Date().timeIntervalSince1970).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)

            await MainActor.run {
                self.exportURL = tempURL
                self.isExporting = false
                HapticManager.success()
            }

        } catch {
            await MainActor.run {
                self.isExporting = false
                self.errorMessage = error.localizedDescription
                self.showError = true
                HapticManager.error()
            }
        }
    }

    private func deleteAccount() async {
        isDeleting = true

        do {
            guard let userId = authService.user?.uid else {
                throw NSError(domain: "Delete", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }

            // For now, we'll directly delete the user data
            // In production, this should be a Cloud Function for security

            // Delete user profile
            try await Firestore.firestore()
                .collection("userProfiles")
                .document(userId)
                .delete()

            // Delete Firebase Auth account
            try await Auth.auth().currentUser?.delete()

            await MainActor.run {
                self.isDeleting = false
                self.isDeletionComplete = true
                HapticManager.success()
            }

        } catch {
            await MainActor.run {
                self.isDeleting = false
                self.errorMessage = "Failed to delete account: \(error.localizedDescription)"
                self.showError = true
                HapticManager.error()
            }
        }
    }
}

// Share Sheet for exporting data
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Extension to make URL Identifiable for sheet
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}