import Foundation

/// Network error types for better error handling
enum NetworkError: LocalizedError {
    case timeout
    case retryExhausted
    case networkUnavailable
    case operationCancelled

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Operation timed out. Please check your connection and try again."
        case .retryExhausted:
            return "Failed after multiple attempts. Please try again later."
        case .networkUnavailable:
            return "No network connection. Please check your internet connection."
        case .operationCancelled:
            return "Operation was cancelled."
        }
    }
}

/// Helper utilities for network operations with timeout and retry logic
struct NetworkHelper {

    /// Execute an async operation with timeout
    static func withTimeout<T>(
        seconds: TimeInterval = 10,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NetworkError.timeout
            }

            // Return first completed task (operation or timeout)
            guard let result = try await group.next() else {
                throw NetworkError.timeout
            }

            // Cancel remaining tasks
            group.cancelAll()
            return result
        }
    }

    /// Execute an async operation with exponential backoff retry
    static func withRetry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                print("Attempt \(attempt) failed: \(error.localizedDescription)")

                // Don't retry on cancellation
                if error is CancellationError {
                    throw NetworkError.operationCancelled
                }

                // Only retry if not the last attempt
                if attempt < maxAttempts {
                    // Exponential backoff: 1s, 2s, 4s, etc.
                    let backoffDelay = delay * pow(2.0, Double(attempt - 1))
                    print("Retrying in \(backoffDelay) seconds...")

                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            }
        }

        // All retries exhausted
        throw lastError ?? NetworkError.retryExhausted
    }

    /// Combine timeout and retry for robust network operations
    static func withTimeoutAndRetry<T>(
        timeout: TimeInterval = 10,
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withRetry(maxAttempts: maxAttempts, delay: delay) {
            try await withTimeout(seconds: timeout) {
                try await operation()
            }
        }
    }
}
