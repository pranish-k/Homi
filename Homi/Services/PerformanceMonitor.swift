import Foundation
import UIKit
// import FirebasePerformance // Uncomment after adding to Package.swift

/// Performance monitoring service for tracking app performance metrics
/// NOTE: This is a placeholder implementation until FirebasePerformance is added
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private var customTraces: [String: Date] = [:]
    private let queue = DispatchQueue(label: "com.homi.performancemonitor", attributes: .concurrent)

    private init() {}

    // MARK: - Trace Management (Placeholder)

    /// Start a custom trace
    func startTrace(_ name: String, attributes: [String: String]? = nil) {
        queue.async(flags: .barrier) { [weak self] in
            self?.customTraces[name] = Date()

            #if DEBUG
            print("📊 PERF: Started trace '\(name)'")
            #endif
        }
    }

    /// Stop a trace and log duration
    func stopTrace(_ name: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let startTime = self?.customTraces[name] else {
                #if DEBUG
                print("⚠️ PERF: No trace found for '\(name)'")
                #endif
                return
            }

            let duration = Date().timeIntervalSince(startTime) * 1000 // ms
            self?.customTraces.removeValue(forKey: name)

            #if DEBUG
            print("📊 PERF: Stopped trace '\(name)' - Duration: \(String(format: "%.2f", duration))ms")
            #endif
        }
    }

    /// Increment a metric value for a specific trace
    func incrementMetric(traceName: String, metricName: String, by value: Int64 = 1) {
        #if DEBUG
        print("📊 PERF: Incremented \(metricName) by \(value) for trace '\(traceName)'")
        #endif
    }

    /// Set a metric value for a specific trace
    func setMetric(traceName: String, metricName: String, value: Int64) {
        #if DEBUG
        print("📊 PERF: Set \(metricName) to \(value) for trace '\(traceName)'")
        #endif
    }

    // MARK: - Convenience Methods

    /// Measure async operation with automatic trace management
    func measure<T>(_ name: String, attributes: [String: String]? = nil, operation: () async throws -> T) async rethrows -> T {
        startTrace(name, attributes: attributes)
        defer { stopTrace(name) }

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // ms

        setMetric(traceName: name, metricName: "\(name)_duration_ms", value: Int64(duration))

        #if DEBUG
        print("📊 PERF: \(name) completed in \(String(format: "%.2f", duration))ms")
        #endif

        return result
    }

    /// Measure sync operation with automatic trace management
    func measureSync<T>(_ name: String, attributes: [String: String]? = nil, operation: () throws -> T) rethrows -> T {
        startTrace(name, attributes: attributes)
        defer { stopTrace(name) }

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // ms

        setMetric(traceName: name, metricName: "\(name)_duration_ms", value: Int64(duration))

        #if DEBUG
        print("📊 PERF: \(name) completed in \(String(format: "%.2f", duration))ms")
        #endif

        return result
    }

    // MARK: - Network Request Monitoring (Placeholder)

    /// Create a custom HTTPMetric for network monitoring (placeholder)
    func startHTTPMetric(url: URL, httpMethod: String) -> String? {
        let metricId = UUID().uuidString
        startTrace("http_\(metricId)")
        return metricId
    }

    /// Stop and record HTTP metric (placeholder)
    func stopHTTPMetric(_ metricId: String?, responseCode: Int? = nil, payloadSize: Int? = nil) {
        guard let metricId = metricId else { return }
        stopTrace("http_\(metricId)")
    }

    // MARK: - Pre-defined Traces

    /// Track app launch performance
    func trackAppLaunch() {
        startTrace("app_launch", attributes: [
            "launch_type": "cold",
            "device_model": UIDevice.current.model
        ])
    }

    /// Track expense loading performance
    func trackExpenseLoad(count: Int) {
        let traceName = "expense_load"
        startTrace(traceName, attributes: ["expense_count": "\(count)"])
        setMetric(traceName: traceName, metricName: "items_loaded", value: Int64(count))
    }

    /// Track payment recording performance
    func trackPaymentRecord(amount: Double) {
        let traceName = "payment_record"
        startTrace(traceName, attributes: ["amount": "\(amount)"])
    }

    /// Track image upload performance
    func trackImageUpload(sizeInBytes: Int) {
        let traceName = "image_upload"
        startTrace(traceName, attributes: ["size_bytes": "\(sizeInBytes)"])
        setMetric(traceName: traceName, metricName: "upload_size", value: Int64(sizeInBytes))
    }

    // MARK: - Performance Thresholds

    /// Check if operation is taking too long and log warning
    func checkPerformanceThreshold(operationName: String, duration: TimeInterval, threshold: TimeInterval) {
        if duration > threshold {
            let exceedBy = duration - threshold

            #if DEBUG
            print("⚠️ PERF WARNING: \(operationName) exceeded threshold by \(String(format: "%.2f", exceedBy * 1000))ms")
            #endif

            // In production, this would log to Crashlytics
            // For now, just log locally
        }
    }
}

// MARK: - Performance Error

enum PerformanceError: LocalizedError {
    case thresholdExceeded(String)

    var errorDescription: String? {
        switch self {
        case .thresholdExceeded(let operation):
            return "Performance threshold exceeded for \(operation)"
        }
    }
}

// MARK: - Usage Examples

/*
 // Example 1: Measure async operation
 let expenses = await PerformanceMonitor.shared.measure("fetch_expenses") {
     try await ExpenseService.shared.getExpenses(houseId: houseId)
 }

 // Example 2: Track with custom metrics
 PerformanceMonitor.shared.startTrace("complex_calculation")
 PerformanceMonitor.shared.setMetric(traceName: "complex_calculation",
                                     metricName: "items_processed",
                                     value: 100)
 // ... do work ...
 PerformanceMonitor.shared.stopTrace("complex_calculation")

 // Example 3: Network monitoring
 let metricId = PerformanceMonitor.shared.startHTTPMetric(url: url, httpMethod: "GET")
 // ... make request ...
 PerformanceMonitor.shared.stopHTTPMetric(metricId, responseCode: 200, payloadSize: 1024)

 // Example 4: Check threshold
 let startTime = Date()
 // ... do operation ...
 let duration = Date().timeIntervalSince(startTime)
 PerformanceMonitor.shared.checkPerformanceThreshold(operationName: "database_query",
                                                     duration: duration,
                                                     threshold: 1.0)
 */