import Foundation
import Darwin

final class CPUMonitor {
    private var previousTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?

    func sample() -> CPUMetrics {
        let host = mach_host_self()
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let info = processorInfo else {
            return CPUMetrics(userPercent: 0, systemPercent: 0, idlePercent: 100)
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<Int32>.stride)
            )
        }

        var totalUser: UInt64 = 0, totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0, totalNice: UInt64 = 0

        for i in 0..<Int(processorCount) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser   += UInt64(info[offset + Int(CPU_STATE_USER)])
            totalSystem += UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle   += UInt64(info[offset + Int(CPU_STATE_IDLE)])
            totalNice   += UInt64(info[offset + Int(CPU_STATE_NICE)])
        }

        let metrics: CPUMetrics
        if let prev = previousTicks {
            let dUser   = totalUser - prev.user
            let dSystem = totalSystem - prev.system
            let dIdle   = totalIdle - prev.idle
            let dNice   = totalNice - prev.nice
            let total   = Double(dUser + dSystem + dIdle + dNice)

            if total > 0 {
                metrics = CPUMetrics(
                    userPercent:   Double(dUser + dNice) / total * 100.0,
                    systemPercent: Double(dSystem) / total * 100.0,
                    idlePercent:   Double(dIdle) / total * 100.0
                )
            } else {
                metrics = CPUMetrics(userPercent: 0, systemPercent: 0, idlePercent: 100)
            }
        } else {
            metrics = CPUMetrics(userPercent: 0, systemPercent: 0, idlePercent: 100)
        }

        previousTicks = (totalUser, totalSystem, totalIdle, totalNice)
        return metrics
    }
}
