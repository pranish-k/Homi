import Foundation
import Combine

/// Thread-safe caching service for expense-related data
final class ExpenseCacheService {
    static let shared = ExpenseCacheService()

    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date
        let ttl: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }

    private var cache: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.homi.expensecache", attributes: .concurrent)

    private init() {}

    // MARK: - Payments Cache (15 minutes TTL)

    func cachePayments(_ payments: [Payment], for key: String) {
        queue.async(flags: .barrier) {
            self.cache[key] = CacheEntry(
                value: payments,
                timestamp: Date(),
                ttl: 900 // 15 minutes
            )
        }
    }

    func getCachedPayments(for key: String) -> [Payment]? {
        queue.sync {
            guard let entry = cache[key] as? CacheEntry<[Payment]>,
                  !entry.isExpired else { return nil }
            return entry.value
        }
    }

    // MARK: - Balance Cache (5 minutes TTL)

    func cacheBalances(_ balances: [Balance], for userId: String) {
        let key = "balances_\(userId)"
        queue.async(flags: .barrier) {
            self.cache[key] = CacheEntry(
                value: balances,
                timestamp: Date(),
                ttl: 300 // 5 minutes
            )
        }
    }

    func getCachedBalances(for userId: String) -> [Balance]? {
        let key = "balances_\(userId)"
        return queue.sync {
            guard let entry = cache[key] as? CacheEntry<[Balance]>,
                  !entry.isExpired else { return nil }
            return entry.value
        }
    }

    // MARK: - Nudge State Cache (30 minutes TTL)

    func cacheNudgeState(_ state: (canNudge: Bool, lastNudgeTime: Date?), for userId: String) async {
        let key = "nudge_\(userId)"
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.cache[key] = CacheEntry(
                    value: state,
                    timestamp: Date(),
                    ttl: 1800 // 30 minutes
                )
                continuation.resume()
            }
        }
    }

    func getCachedNudgeState(for userId: String) async -> (canNudge: Bool, lastNudgeTime: Date?)? {
        let key = "nudge_\(userId)"
        return await withCheckedContinuation { continuation in
            queue.async {
                let result: (canNudge: Bool, lastNudgeTime: Date?)? = {
                    guard let entry = self.cache[key] as? CacheEntry<(canNudge: Bool, lastNudgeTime: Date?)>,
                          !entry.isExpired else { return nil }
                    return entry.value
                }()
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Cache Management

    func invalidateCache(for pattern: String? = nil) {
        queue.async(flags: .barrier) {
            if let pattern = pattern {
                self.cache = self.cache.filter { !$0.key.contains(pattern) }
            } else {
                self.cache.removeAll()
            }
        }
    }

    func invalidateExpiredEntries() {
        queue.async(flags: .barrier) {
            for (key, value) in self.cache {
                if let entry = value as? CacheEntry<Any>, entry.isExpired {
                    self.cache.removeValue(forKey: key)
                }
            }
        }
    }

    var cacheSize: Int {
        queue.sync { cache.count }
    }
}
