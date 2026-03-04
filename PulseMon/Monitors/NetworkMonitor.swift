import Foundation
import Darwin

final class NetworkMonitor {
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousTimestamp: Date?

    func sample() -> NetworkMetrics {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return NetworkMetrics(uploadBytesPerSecond: 0, downloadBytesPerSecond: 0)
        }
        defer { freeifaddrs(ifaddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = cursor {
            if Int32(addr.pointee.ifa_addr.pointee.sa_family) == AF_LINK {
                let name = String(cString: addr.pointee.ifa_name)
                if name != "lo0" {
                    let data = unsafeBitCast(
                        addr.pointee.ifa_data,
                        to: UnsafeMutablePointer<if_data>.self
                    )
                    totalIn  += UInt64(data.pointee.ifi_ibytes)
                    totalOut += UInt64(data.pointee.ifi_obytes)
                }
            }
            cursor = addr.pointee.ifa_next
        }

        let now = Date()
        let metrics: NetworkMetrics

        if let prevTime = previousTimestamp {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                let deltaIn  = totalIn >= previousBytesIn ? totalIn - previousBytesIn : totalIn
                let deltaOut = totalOut >= previousBytesOut ? totalOut - previousBytesOut : totalOut
                metrics = NetworkMetrics(
                    uploadBytesPerSecond: UInt64(Double(deltaOut) / elapsed),
                    downloadBytesPerSecond: UInt64(Double(deltaIn) / elapsed)
                )
            } else {
                metrics = NetworkMetrics(uploadBytesPerSecond: 0, downloadBytesPerSecond: 0)
            }
        } else {
            metrics = NetworkMetrics(uploadBytesPerSecond: 0, downloadBytesPerSecond: 0)
        }

        previousBytesIn = totalIn
        previousBytesOut = totalOut
        previousTimestamp = now
        return metrics
    }
}
