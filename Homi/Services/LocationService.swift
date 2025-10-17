import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import OSLog
import Combine

// MARK: - Location Service

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    // Published properties
    @Published var userLocations: [UserLocation] = []
    @Published var currentUserLocation: UserLocation?
    @Published var isLocationSharingEnabled: Bool = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    // Private properties
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private var locationsListener: ListenerRegistration?
    private var currentHouseId: String?
    private let logger = Logger(subsystem: "com.homi.app", category: "LocationService")

    // Location update settings
    private let updateInterval: TimeInterval = 300 // 5 minutes
    private var lastUpdateTime: Date?

    override private init() {
        super.init()
        setupLocationManager()
        loadSharingPreference()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        // Use lower accuracy for better battery life - 100 meters is sufficient for roommate tracking
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Update every 500 meters to reduce battery drain
        locationManager.distanceFilter = 500
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        // Show blue bar when app is using location
        locationManager.showsBackgroundLocationIndicator = false

        // Check authorization status
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Authorization

    func requestLocationPermission() {
        logger.info("Requesting location permission")
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Location Sharing Control

    func startSharingLocation(houseId: String) {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Location permission not granted"
            logger.warning("Cannot start sharing: permission not granted")
            return
        }

        logger.info("Starting location sharing for house: \(houseId)")
        currentHouseId = houseId
        isLocationSharingEnabled = true
        saveSharingPreference(true)

        // Start location updates
        locationManager.startUpdatingLocation()

        // Request location immediately
        locationManager.requestLocation()
    }

    func stopSharingLocation() {
        logger.info("Stopping location sharing")
        isLocationSharingEnabled = false
        saveSharingPreference(false)

        // Stop location updates
        locationManager.stopUpdatingLocation()

        // Update Firestore to mark as not sharing
        if let houseId = currentHouseId,
           let userId = AuthService.shared.user?.uid {
            updateSharingStatus(houseId: houseId, userId: userId, isSharing: false)
        }
    }

    // MARK: - Firestore Operations

    func startListening(houseId: String) {
        logger.info("Starting to listen for location updates in house: \(houseId)")
        currentHouseId = houseId

        // Stop any existing listener
        stopListening()

        // Listen to locations collection
        locationsListener = db.collection("houses")
            .document(houseId)
            .collection("locations")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.logger.error("Error listening to locations: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.logger.warning("No location documents found")
                    return
                }

                Task { @MainActor in
                    self.userLocations = documents.compactMap { UserLocation(document: $0) }
                        .filter { $0.isSharingEnabled } // Only show users actively sharing
                    self.logger.info("Updated locations: \(self.userLocations.count) users sharing")

                    // Update current user location if present
                    if let userId = AuthService.shared.user?.uid {
                        self.currentUserLocation = self.userLocations.first { $0.userId == userId }
                    }
                }
            }
    }

    func stopListening() {
        logger.info("Stopping location listener")
        locationsListener?.remove()
        locationsListener = nil
    }

    private func updateLocation(_ location: CLLocation, houseId: String, userId: String) {
        // Throttle updates to avoid excessive writes
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < updateInterval {
            logger.debug("Skipping location update (throttled)")
            return
        }

        guard let userName = AuthService.shared.userProfile?.displayName else {
            logger.warning("Cannot update location: user name not available")
            return
        }

        let userLocation = UserLocation(
            userId: userId,
            userName: userName,
            userPhotoURL: AuthService.shared.userProfile?.profilePhotoUrl,
            location: location,
            isSharingEnabled: isLocationSharingEnabled
        )

        let locationRef = db.collection("houses")
            .document(houseId)
            .collection("locations")
            .document(userId)

        locationRef.setData(userLocation.toFirestore(), merge: true) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Error updating location: \(error.localizedDescription)")
                Task { @MainActor in
                    self.errorMessage = "Failed to update location"
                }
            } else {
                self.logger.info("Location updated successfully")

                Task { @MainActor in
                    self.lastUpdateTime = Date()
                    self.currentUserLocation = userLocation
                }
            }
        }
    }

    private func updateSharingStatus(houseId: String, userId: String, isSharing: Bool) {
        let locationRef = db.collection("houses")
            .document(houseId)
            .collection("locations")
            .document(userId)

        locationRef.updateData(["isSharingEnabled": isSharing]) { [weak self] error in
            if let error = error {
                self?.logger.error("Error updating sharing status: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - User Defaults

    private func saveSharingPreference(_ isSharing: Bool) {
        UserDefaults.standard.set(isSharing, forKey: "locationSharingEnabled")
    }

    private func loadSharingPreference() {
        isLocationSharingEnabled = UserDefaults.standard.bool(forKey: "locationSharingEnabled")
    }

    // MARK: - Cleanup

    func cleanup() {
        stopListening()
        stopSharingLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            logger.debug("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            // Only update if sharing is enabled
            guard isLocationSharingEnabled,
                  let houseId = currentHouseId,
                  let userId = AuthService.shared.user?.uid else {
                return
            }

            updateLocation(location, houseId: houseId, userId: userId)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Location manager failed: \(error.localizedDescription)")

            // Handle specific errors
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    errorMessage = "Location access denied. Enable in Settings."
                case .locationUnknown:
                    errorMessage = "Unable to determine location."
                default:
                    errorMessage = "Location error: \(error.localizedDescription)"
                }
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            authorizationStatus = status
            logger.info("Location authorization changed: \(status.rawValue)")

            // Handle authorization changes
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if isLocationSharingEnabled, currentHouseId != nil {
                    manager.startUpdatingLocation()
                }
            case .denied, .restricted:
                stopSharingLocation()
                errorMessage = "Location permission denied. Enable in Settings to share your location."
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}
