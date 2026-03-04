import Foundation

extension ByteCountFormatter {
    private static let sharedMemoryFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .memory
        return f
    }()

    private static let sharedRateFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .memory
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f
    }()

    static func humanReadable(_ bytes: UInt64) -> String {
        sharedMemoryFormatter.string(fromByteCount: Int64(bytes))
    }

    static func shortRate(_ bytesPerSecond: UInt64) -> String {
        if bytesPerSecond < 1024 {
            return "\(bytesPerSecond) B/s"
        }
        return "\(sharedRateFormatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }
}
