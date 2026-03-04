import Foundation
import Darwin

final class MemoryMonitor {
    func sample() -> MemoryMetrics {
        let host = mach_host_self()
        let totalBytes = UInt64(ProcessInfo.processInfo.physicalMemory)

        do {
            let stats: vm_statistics64 = try hostStatistics64(
                host,
                flavor: HOST_VM_INFO64,
                as: vm_statistics64.self
            )

            let pageSize = UInt64(vm_kernel_page_size)
            let active     = UInt64(stats.active_count) * pageSize
            let wired      = UInt64(stats.wire_count) * pageSize
            let compressed = UInt64(stats.compressor_page_count) * pageSize
            let used = active + wired + compressed
            let free = totalBytes > used ? totalBytes - used : 0

            return MemoryMetrics(
                totalBytes: totalBytes,
                usedBytes: used,
                freeBytes: free,
                activeBytes: active,
                wiredBytes: wired,
                compressedBytes: compressed
            )
        } catch {
            return MemoryMetrics(
                totalBytes: totalBytes, usedBytes: 0, freeBytes: totalBytes,
                activeBytes: 0, wiredBytes: 0, compressedBytes: 0
            )
        }
    }
}
