import Foundation

struct CPUMetrics: Equatable {
    let userPercent: Double
    let systemPercent: Double
    let idlePercent: Double
    var totalUsage: Double { userPercent + systemPercent }
}

struct MemoryMetrics: Equatable {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let freeBytes: UInt64
    let activeBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    var usagePercent: Double { Double(usedBytes) / Double(max(totalBytes, 1)) * 100.0 }
}

struct DiskMetrics: Equatable {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let freeBytes: UInt64
    var usagePercent: Double { Double(usedBytes) / Double(max(totalBytes, 1)) * 100.0 }
}

struct NetworkMetrics: Equatable {
    let uploadBytesPerSecond: UInt64
    let downloadBytesPerSecond: UInt64
}

struct SystemSnapshot: Equatable {
    let cpu: CPUMetrics
    let memory: MemoryMetrics
    let disk: DiskMetrics
    let network: NetworkMetrics
    let timestamp: Date
}
