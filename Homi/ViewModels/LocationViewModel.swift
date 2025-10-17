import Foundation
import SwiftUI
import MapKit
import Combine
import OSLog
import FirebaseAuth

// MARK: - Location ViewModel

@MainActor
class LocationViewModel: ObservableObject {
    // Published properties
    @Published var userLocations: [UserLocation] = []
    @Published var isLocationSharingEnabled: Bool = false
    @Published var mapRegion: MKCoordinateRegion
    @Published var showPermissionAlert = false
    @Published var errorMessage: String?

    // Private properties
    private let locationService = LocationService.shared
    private let authService = AuthService.shared
    private let logger = Logger(subsystem: "com.homi.app", category: "LocationViewModel")
    private var cancellables = Set<AnyCancellable>()

    // Default map region (San Francisco)
    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    init() {
        self.mapRegion = LocationViewModel.defaultRegion
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Subscribe to location service updates
        locationService.$userLocations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] locations in
                self?.userLocations = locations
                self?.updateMapRegion()
            }
            .store(in: &cancellables)

        locationService.$isLocationSharingEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLocationSharingEnabled)

        locationService.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func startListening() {
        guard let houseId = authService.userProfile?.currentHouseId else {
            logger.warning("Cannot start listening: no house ID")
            return
        }

        logger.info("Starting location updates for house: \(houseId)")
        locationService.startListening(houseId: houseId)
    }

    func stopListening() {
        logger.info("Stopping location updates")
        locationService.stopListening()
    }

    // MARK: - Location Sharing Control

    func toggleLocationSharing() {
        if isLocationSharingEnabled {
            // Turn off
            stopSharing()
        } else {
            // Turn on - check permissions first
            startSharing()
        }
    }

    private func startSharing() {
        // Check authorization status
        switch locationService.authorizationStatus {
        case .notDetermined:
            // Request permission
            locationService.requestLocationPermission()
            // Wait for callback to handle the result
            return

        case .denied, .restricted:
            // Show alert to go to settings
            showPermissionAlert = true
            return

        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted, start sharing
            guard let houseId = authService.userProfile?.currentHouseId else {
                errorMessage = "No house found"
                return
            }
            locationService.startSharingLocation(houseId: houseId)

        @unknown default:
            errorMessage = "Unknown authorization status"
        }
    }

    private func stopSharing() {
        locationService.stopSharingLocation()
    }

    // MARK: - Map Management

    private func updateMapRegion() {
        // If we have locations, center the map to show all of them
        guard !userLocations.isEmpty else {
            // Use default region or current user location
            if let currentLocation = locationService.currentUserLocation {
                mapRegion = MKCoordinateRegion(
                    center: currentLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
            return
        }

        // Calculate region that fits all locations
        let coordinates = userLocations.map { $0.coordinate }
        let region = calculateRegion(for: coordinates)
        mapRegion = region
    }

    func centerOnUser(_ userId: String) {
        guard let userLocation = userLocations.first(where: { $0.userId == userId }) else {
            return
        }

        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    func centerOnCurrentUser() {
        guard let userId = authService.user?.uid else { return }
        centerOnUser(userId)
    }

    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return LocationViewModel.defaultRegion
        }

        // Find min/max coordinates
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        // Calculate center and span
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = (maxLat - minLat) * 1.5 // Add 50% padding
        let spanLon = (maxLon - minLon) * 1.5

        // Ensure minimum span
        let finalSpanLat = max(spanLat, 0.01)
        let finalSpanLon = max(spanLon, 0.01)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: finalSpanLat, longitudeDelta: finalSpanLon)
        )
    }

    // MARK: - Filtering

    func activeSharingUsers() -> [UserLocation] {
        userLocations.filter { $0.isSharingEnabled && $0.isRecent }
    }

    func inactiveSharingUsers() -> [UserLocation] {
        userLocations.filter { !$0.isRecent || !$0.isSharingEnabled }
    }

    // MARK: - Helpers

    func isCurrentUser(_ location: UserLocation) -> Bool {
        location.userId == authService.user?.uid
    }

    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        stopListening()
        cancellables.removeAll()
    }
}
