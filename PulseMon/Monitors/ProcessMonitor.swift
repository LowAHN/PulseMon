import Foundation
import Darwin

// libproc declarations
@_silgen_name("proc_listallpids")
private func proc_listallpids(_ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

@_silgen_name("proc_pidinfo")
private func proc_pidinfo(
    _ pid: Int32,
    _ flavor: Int32,
    _ arg: UInt64,
    _ buffer: UnsafeMutableRawPointer?,
    _ buffersize: Int32
) -> Int32

@_silgen_name("proc_name")
private func proc_name(_ pid: Int32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: UInt32) -> Int32

@_silgen_name("proc_pid_rusage")
private func proc_pid_rusage(_ pid: Int32, _ flavor: Int32, _ buffer: UnsafeMutablePointer<rusage_info_v3>) -> Int32

private let PROC_PIDTBSDINFO: Int32 = 3
private let PROC_PIDTBSDINFO_SIZE: Int32 = Int32(MemoryLayout<proc_bsdinfo>.size)
private let RUSAGE_INFO_V3: Int32 = 3

final class ProcessMonitor {
    private var previousCPUTimes: [pid_t: (user: UInt64, system: UInt64, timestamp: Date)] = [:]
    private var uidNameCache: [UInt32: String] = [:]

    func sample() -> [ProcessEntry] {
        let pids = listAllPids()
        var entries: [ProcessEntry] = []
        entries.reserveCapacity(pids.count)
        let now = Date()

        for pid in pids {
            guard let entry = processInfo(for: pid, now: now) else { continue }
            entries.append(entry)
        }

        // Clean up stale entries
        let activePids = Set(pids)
        previousCPUTimes = previousCPUTimes.filter { activePids.contains($0.key) }

        return entries
    }

    func terminateProcess(pid: pid_t, force: Bool) -> Bool {
        let signal: Int32 = force ? SIGKILL : SIGTERM
        return kill(pid, signal) == 0
    }

    private func listAllPids() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(count) * 2)
        let actual = proc_listallpids(&pids, Int32(pids.count) * Int32(MemoryLayout<pid_t>.size))
        guard actual > 0 else { return [] }

        return Array(pids.prefix(Int(actual))).filter { $0 > 0 }
    }

    private func processInfo(for pid: pid_t, now: Date) -> ProcessEntry? {
        // Get process name
        var nameBuffer = [CChar](repeating: 0, count: 256)
        let nameLen = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        let name: String
        if nameLen > 0 {
            name = String(cString: nameBuffer)
        } else {
            name = "(unknown)"
        }

        // Get BSD info for status and UID
        var bsdInfo = proc_bsdinfo()
        let bsdSize = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, PROC_PIDTBSDINFO_SIZE)

        let user: String
        let status: String

        if bsdSize > 0 {
            user = userName(for: bsdInfo.pbi_uid)
            status = processStatus(flags: bsdInfo.pbi_status)
        } else {
            user = "?"
            status = "?"
        }

        // Get resource usage for CPU and memory
        var rusage = rusage_info_v3()
        let rusageResult = proc_pid_rusage(pid, RUSAGE_INFO_V3, &rusage)

        let memoryBytes: UInt64
        let cpuUsage: Double

        if rusageResult == 0 {
            memoryBytes = rusage.ri_phys_footprint

            let currentUser = rusage.ri_user_time
            let currentSystem = rusage.ri_system_time
            let totalCPU = currentUser + currentSystem

            if let prev = previousCPUTimes[pid] {
                let elapsed = now.timeIntervalSince(prev.timestamp)
                if elapsed > 0 {
                    let prevTotal = prev.user + prev.system
                    let delta = totalCPU > prevTotal ? totalCPU - prevTotal : 0
                    // ri_user_time and ri_system_time are in nanoseconds
                    cpuUsage = (Double(delta) / 1_000_000_000.0) / elapsed * 100.0
                } else {
                    cpuUsage = 0
                }
            } else {
                cpuUsage = 0
            }

            previousCPUTimes[pid] = (user: currentUser, system: currentSystem, timestamp: now)
        } else {
            memoryBytes = 0
            cpuUsage = 0
        }

        return ProcessEntry(
            pid: pid,
            name: name,
            cpuUsage: cpuUsage,
            memoryBytes: memoryBytes,
            user: user,
            status: status
        )
    }

    private func userName(for uid: UInt32) -> String {
        if let cached = uidNameCache[uid] { return cached }
        guard let pw = getpwuid(uid) else { return "\(uid)" }
        let name = String(cString: pw.pointee.pw_name)
        uidNameCache[uid] = name
        return name
    }

    private func processStatus(flags: UInt32) -> String {
        switch flags {
        case 1: return "Idle"
        case 2: return "Running"
        case 3: return "Sleeping"
        case 4: return "Stopped"
        case 5: return "Zombie"
        default: return "Running"
        }
    }
}
