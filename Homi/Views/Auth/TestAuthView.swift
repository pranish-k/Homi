import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct TestAuthView: View {
    @State private var testResult = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Authentication Test")
                .font(.title)
                .fontWeight(.bold)

            // Test Firebase Connection
            Button(action: testFirebaseConnection) {
                Label("Test Firebase Connection", systemImage: "network")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            // Test Firestore Write
            Button(action: testFirestoreWrite) {
                Label("Test Firestore Write", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            // Test Auth Creation
            Button(action: testAuthCreation) {
                Label("Test Auth User Creation", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }

            ScrollView {
                Text(testResult)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
    }

    func testFirebaseConnection() {
        isLoading = true
        testResult = "Testing Firebase connection...\n"

        if let app = FirebaseApp.app() {
            testResult += "✅ Firebase App initialized\n"
            testResult += "Project ID: \(String(describing: app.options.projectID))\n"
            testResult += "Bundle ID: \(app.options.bundleID)\n"
        } else {
            testResult += "❌ Firebase App not initialized\n"
        }

        // Test Auth
        let auth = Auth.auth()
        if let currentUser = auth.currentUser {
            testResult += "✅ Current user: \(currentUser.uid)\n"
        } else {
            testResult += "ℹ️ No user currently signed in\n"
        }

        isLoading = false
    }

    func testFirestoreWrite() {
        isLoading = true
        testResult = "Testing Firestore write...\n"

        let db = Firestore.firestore()
        let testDoc = db.collection("test").document("test_\(UUID().uuidString)")

        testDoc.setData([
            "message": "Test write from iOS app",
            "timestamp": Timestamp(date: Date()),
            "device": "iOS Simulator"
        ]) { error in
            if let error = error {
                testResult += "❌ Firestore write failed: \(error.localizedDescription)\n"
            } else {
                testResult += "✅ Firestore write successful!\n"
                testResult += "Document ID: \(testDoc.documentID)\n"
            }
            isLoading = false
        }
    }

    func testAuthCreation() {
        isLoading = true
        testResult = "Testing Auth user creation...\n"

        let testEmail = "test_\(UUID().uuidString.prefix(8))@test.com"
        let testPassword = "TestPass123!"

        Auth.auth().createUser(withEmail: testEmail, password: testPassword) { result, error in
            if let error = error {
                testResult += "❌ Auth creation failed: \(error.localizedDescription)\n"
            } else if let user = result?.user {
                testResult += "✅ Auth user created!\n"
                testResult += "User ID: \(user.uid)\n"
                testResult += "Email: \(user.email ?? "none")\n"

                // Try to delete the test user
                user.delete { deleteError in
                    if let deleteError = deleteError {
                        testResult += "⚠️ Could not delete test user: \(deleteError.localizedDescription)\n"
                    } else {
                        testResult += "✅ Test user deleted\n"
                    }
                }
            }
            isLoading = false
        }
    }
}