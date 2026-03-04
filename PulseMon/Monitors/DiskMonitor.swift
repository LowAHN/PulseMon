import Foundation

final class DiskMonitor {
    func sample() -> DiskMetrics {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = attrs[.systemSize] as? UInt64 ?? 0
            let free  = attrs[.systemFreeSize] as? UInt64 ?? 0
            let used  = total > free ? total - free : 0
            return DiskMetrics(totalBytes: total, usedBytes: used, freeBytes: free)
        } catch {
            return DiskMetrics(totalBytes: 0, usedBytes: 0, freeBytes: 0)
        }
    }
}
