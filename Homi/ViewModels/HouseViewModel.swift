import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class HouseViewModel: ObservableObject {
    @Published var currentStep: HouseSetupStep = .createOrJoin
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // Create house properties
    @Published var houseName = ""
    @Published var houseAddress = ""

    // Join house properties
    @Published var inviteCode = ""

    // Success properties
    @Published var createdHouse: House?
    @Published var generatedInviteCode = ""

    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    enum HouseSetupStep {
        case createOrJoin
        case createHouse
        case joinHouse
        case setupComplete
    }

    // MARK: - Create House

    func createHouse() async {
        guard validateHouseCreation() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let house = try await firestoreService.createHouse(
                name: houseName,
                address: houseAddress.isEmpty ? nil : houseAddress
            )

            createdHouse = house
            generatedInviteCode = house.inviteCode
            currentStep = .setupComplete

            // Update auth service with new house
            if Auth.auth().currentUser?.uid != nil {
                authService.userProfile?.currentHouseId = house.id
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    // MARK: - Join House

    func joinHouse() async {
        guard validateInviteCode() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let house = try await firestoreService.joinHouse(inviteCode: inviteCode.uppercased())

            createdHouse = house
            generatedInviteCode = house.inviteCode
            currentStep = .setupComplete

            // Update auth service with new house
            if Auth.auth().currentUser?.uid != nil {
                authService.userProfile?.currentHouseId = house.id
            }
        } catch {
            if case FirestoreError.alreadyMember = error {
                errorMessage = "You're already a member of this house"
            } else if case FirestoreError.invalidInviteCode = error {
                errorMessage = "Invalid invite code. Please check and try again."
            } else if case FirestoreError.expiredInviteCode = error {
                errorMessage = "This invite code has expired"
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }

        isLoading = false
    }

    // MARK: - Validation

    private func validateHouseCreation() -> Bool {
        if houseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter a house name"
            showError = true
            return false
        }

        if houseName.count < 2 {
            errorMessage = "House name must be at least 2 characters"
            showError = true
            return false
        }

        if houseName.count > 50 {
            errorMessage = "House name must be less than 50 characters"
            showError = true
            return false
        }

        return true
    }

    private func validateInviteCode() -> Bool {
        let cleanedCode = inviteCode.replacingOccurrences(of: " ", with: "").uppercased()

        if cleanedCode.isEmpty {
            errorMessage = "Please enter an invite code"
            showError = true
            return false
        }

        if cleanedCode.count != Constants.Validation.inviteCodeLength {
            errorMessage = "Invite code must be \(Constants.Validation.inviteCodeLength) characters"
            showError = true
            return false
        }

        inviteCode = cleanedCode
        return true
    }

    // MARK: - Navigation

    func navigateToCreateHouse() {
        currentStep = .createHouse
        houseName = ""
        houseAddress = ""
    }

    func navigateToJoinHouse() {
        currentStep = .joinHouse
        inviteCode = ""
    }

    func navigateBack() {
        switch currentStep {
        case .createOrJoin:
            break
        case .createHouse, .joinHouse:
            currentStep = .createOrJoin
        case .setupComplete:
            // Can't go back from completion
            break
        }

        errorMessage = nil
        showError = false
    }

    func reset() {
        currentStep = .createOrJoin
        houseName = ""
        houseAddress = ""
        inviteCode = ""
        createdHouse = nil
        generatedInviteCode = ""
        errorMessage = nil
        showError = false
    }
}