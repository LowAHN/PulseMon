import Foundation

struct ProcessEntry: Identifiable {
    let pid: pid_t
    let name: String
    let cpuUsage: Double        // %
    let memoryBytes: UInt64     // RSS
    let user: String
    let status: String          // Running, Sleeping, etc.

    var id: pid_t { pid }
}
