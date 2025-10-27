import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import OSLog

@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let logger = Logger(subsystem: "com.homi.app", category: "FirestoreService")

    @Published var currentHouse: House?
    @Published var houseMembers: [HouseMember] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        setupFirestoreSettings()
    }

    private func setupFirestoreSettings() {
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 50 * 1024 * 1024)) // 50MB
        db.settings = settings
    }

    // MARK: - User Operations

    func createUser(_ user: User) async throws {
        do {
            try await db.collection(Constants.Collections.users)
                .document(user.id)
                .setData(user.toFirestore)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func getUser(id: String) async throws -> User? {
        do {
            let document = try await db.collection(Constants.Collections.users)
                .document(id)
                .getDocument()

            return User(document: document)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func updateUser(id: String, data: [String: Any]) async throws {
        do {
            try await db.collection(Constants.Collections.users)
                .document(id)
                .updateData(data)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - House Operations

    func createHouse(name: String, address: String? = nil) async throws -> House {
        guard let userId = auth.currentUser?.uid else {
            throw FirestoreError.noUser
        }

        let inviteCode = try await generateInviteCode()
        let houseId = db.collection(Constants.Collections.houses).document().documentID

        let house = House(
            id: houseId,
            name: name,
            address: address,
            inviteCode: inviteCode,
            createdBy: userId,
            memberIds: [userId]
        )

        do {
            // Create house document
            try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .setData(house.toFirestore)

            // Create invite code document
            let inviteData: [String: Any] = [
                "houseId": houseId,
                "houseName": name,
                "createdBy": userId,
                "createdAt": Timestamp(date: Date()),
                "expiresAt": Timestamp(date: Date().addingTimeInterval(7 * 24 * 60 * 60)), // 7 days
                "currentUses": 0
            ]

            try await db.collection(Constants.Collections.invites)
                .document(inviteCode)
                .setData(inviteData)

            // Add user as member
            let memberData: [String: Any] = [
                "userId": userId,
                "displayName": AuthService.shared.userProfile?.displayName ?? "",
                "profilePhotoUrl": AuthService.shared.userProfile?.profilePhotoUrl ?? NSNull(),
                "role": HouseMember.MemberRole.admin.rawValue,
                "joinedAt": Timestamp(date: Date()),
                "locationSharing": false
            ]

            try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.members)
                .document(userId)
                .setData(memberData)

            // Update user's currentHouseId
            try await updateUser(id: userId, data: ["currentHouseId": houseId])

            self.currentHouse = house

            return house
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func joinHouse(inviteCode: String) async throws -> House {
        guard let userId = auth.currentUser?.uid else {
            throw FirestoreError.noUser
        }

        do {
            // Get invite document
            let inviteDoc = try await db.collection(Constants.Collections.invites)
                .document(inviteCode.uppercased())
                .getDocument()

            guard inviteDoc.exists,
                  let inviteData = inviteDoc.data(),
                  let houseId = inviteData["houseId"] as? String else {
                throw FirestoreError.invalidInviteCode
            }

            // Check if invite is expired
            if let expiresAt = inviteData["expiresAt"] as? Timestamp,
               expiresAt.dateValue() < Date() {
                throw FirestoreError.expiredInviteCode
            }

            // Get house document
            let houseDoc = try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .getDocument()

            guard let house = House(document: houseDoc) else {
                throw FirestoreError.houseNotFound
            }

            // Check if user is already a member
            if house.memberIds.contains(userId) {
                throw FirestoreError.alreadyMember
            }

            // Add user to house
            let batch = db.batch()

            // Update house memberIds and count
            var updatedMemberIds = house.memberIds
            updatedMemberIds.append(userId)

            batch.updateData([
                "memberIds": updatedMemberIds,
                "memberCount": FieldValue.increment(Int64(1))
            ], forDocument: db.collection(Constants.Collections.houses).document(houseId))

            // Add user as member
            let memberData: [String: Any] = [
                "userId": userId,
                "displayName": AuthService.shared.userProfile?.displayName ?? "",
                "profilePhotoUrl": AuthService.shared.userProfile?.profilePhotoUrl ?? NSNull(),
                "role": HouseMember.MemberRole.member.rawValue,
                "joinedAt": Timestamp(date: Date()),
                "locationSharing": false
            ]

            batch.setData(memberData, forDocument: db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.members)
                .document(userId))

            // Update user's currentHouseId
            batch.updateData(["currentHouseId": houseId],
                           forDocument: db.collection(Constants.Collections.users).document(userId))

            // Update invite usage count
            batch.updateData(["currentUses": FieldValue.increment(Int64(1))],
                           forDocument: db.collection(Constants.Collections.invites).document(inviteCode.uppercased()))

            // Commit batch
            try await batch.commit()

            self.currentHouse = house

            return house
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func getHouse(id: String) async throws -> House? {
        do {
            let document = try await db.collection(Constants.Collections.houses)
                .document(id)
                .getDocument()

            return House(document: document)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func getHouseMembers(houseId: String) async throws -> [HouseMember] {
        do {
            let snapshot = try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.members)
                .getDocuments()

            let members = snapshot.documents.compactMap { document -> HouseMember? in
                let data = document.data()

                let joinedAt: Date
                if let timestamp = data["joinedAt"] as? Timestamp {
                    joinedAt = timestamp.dateValue()
                } else {
                    joinedAt = Date()
                }

                return HouseMember(
                    userId: data["userId"] as? String ?? "",
                    displayName: data["displayName"] as? String ?? "",
                    profilePhotoUrl: data["profilePhotoUrl"] as? String,
                    role: HouseMember.MemberRole(rawValue: data["role"] as? String ?? "member") ?? .member,
                    joinedAt: joinedAt,
                    locationSharing: data["locationSharing"] as? Bool ?? false,
                    lastLocation: nil
                )
            }

            self.houseMembers = members
            return members
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func leaveHouse(houseId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw FirestoreError.noUser
        }

        do {
            let batch = db.batch()

            // Get house document
            let houseDoc = try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .getDocument()

            guard let house = House(document: houseDoc) else {
                throw FirestoreError.houseNotFound
            }

            // Check if user is the last member
            if house.memberCount <= 1 {
                // Delete the house if last member
                batch.deleteDocument(db.collection(Constants.Collections.houses).document(houseId))
                // Delete the invite code
                batch.deleteDocument(db.collection(Constants.Collections.invites).document(house.inviteCode))
            } else {
                // Remove user from memberIds
                var updatedMemberIds = house.memberIds
                updatedMemberIds.removeAll { $0 == userId }

                batch.updateData([
                    "memberIds": updatedMemberIds,
                    "memberCount": FieldValue.increment(Int64(-1))
                ], forDocument: db.collection(Constants.Collections.houses).document(houseId))

                // Remove member document
                batch.deleteDocument(db.collection(Constants.Collections.houses)
                    .document(houseId)
                    .collection(Constants.Collections.members)
                    .document(userId))
            }

            // Update user's currentHouseId to nil
            batch.updateData(["currentHouseId": FieldValue.delete()],
                           forDocument: db.collection(Constants.Collections.users).document(userId))

            try await batch.commit()

            self.currentHouse = nil
            self.houseMembers = []
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Admin Operations

    func updateHouseName(houseId: String, name: String) async throws {
        try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .updateData(["name": name])

        self.logger.info("House name updated successfully")
    }

    func removeMemberFromHouse(houseId: String, memberId: String) async throws {
        let batch = db.batch()

        // Remove member document
        let memberRef = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.members)
            .document(memberId)
        batch.deleteDocument(memberRef)

        // Update house member count and memberIds
        let houseRef = db.collection(Constants.Collections.houses).document(houseId)
        batch.updateData([
            "memberIds": FieldValue.arrayRemove([memberId]),
            "memberCount": FieldValue.increment(Int64(-1))
        ], forDocument: houseRef)

        // Update user's currentHouseId to nil
        let userRef = db.collection(Constants.Collections.users).document(memberId)
        batch.updateData(["currentHouseId": FieldValue.delete()], forDocument: userRef)

        try await batch.commit()

        self.logger.info("Member removed from house successfully")
    }

    // MARK: - Helper Methods

    private func generateInviteCode() async throws -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var attempts = 0
        let maxAttempts = 5

        // Retry until we get a unique code
        while attempts < maxAttempts {
            let code = String((0..<Constants.Validation.inviteCodeLength).map { _ in letters.randomElement()! })

            // Check if code already exists
            let existingInvite = try await db.collection(Constants.Collections.invites)
                .document(code)
                .getDocument()

            if !existingInvite.exists {
                return code
            }

            attempts += 1
        }

        // If we couldn't generate a unique code, throw an error
        throw FirestoreError.inviteCodeGenerationFailed
    }
}

// MARK: - Firestore Errors

enum FirestoreError: LocalizedError {
    case noUser
    case invalidInviteCode
    case expiredInviteCode
    case houseNotFound
    case alreadyMember
    case inviteCodeGenerationFailed

    var errorDescription: String? {
        switch self {
        case .noUser:
            return "No user logged in"
        case .invalidInviteCode:
            return "Invalid invite code"
        case .expiredInviteCode:
            return "This invite code has expired"
        case .houseNotFound:
            return "House not found"
        case .alreadyMember:
            return "You are already a member of this house"
        case .inviteCodeGenerationFailed:
            return "Failed to generate unique invite code. Please try again."
        }
    }
}