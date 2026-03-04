import Foundation

enum Benchmark {
    static func run() {
        print("=== PulseMon Performance Benchmark ===\n")

        let processMonitor = ProcessMonitor()
        let cpuMonitor = CPUMonitor()
        let memoryMonitor = MemoryMonitor()
        let diskMonitor = DiskMonitor()
        let networkMonitor = NetworkMonitor()

        // Prime monitors
        _ = cpuMonitor.sample()
        _ = networkMonitor.sample()
        _ = processMonitor.sample()
        Thread.sleep(forTimeInterval: 1.0)

        // --- Benchmark ProcessMonitor ---
        print("[1] ProcessMonitor.sample() — 10 iterations")
        var processCounts: [Int] = []
        let procStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<10 {
            let entries = processMonitor.sample()
            processCounts.append(entries.count)
        }
        let procElapsed = CFAbsoluteTimeGetCurrent() - procStart
        let avgProcs = processCounts.reduce(0, +) / processCounts.count
        print("    Total: \(String(format: "%.3f", procElapsed))s")
        print("    Avg per call: \(String(format: "%.1f", procElapsed / 10.0 * 1000))ms")
        print("    Processes found: \(avgProcs)")

        // --- Benchmark CPU Monitor ---
        print("\n[2] CPUMonitor.sample() — 100 iterations")
        let cpuStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 { _ = cpuMonitor.sample() }
        let cpuElapsed = CFAbsoluteTimeGetCurrent() - cpuStart
        let lastCPU = cpuMonitor.sample()
        print("    Total: \(String(format: "%.3f", cpuElapsed))s")
        print("    Avg per call: \(String(format: "%.3f", cpuElapsed / 100.0 * 1000))ms")
        print("    Current CPU: \(String(format: "%.1f", lastCPU.totalUsage))%")

        // --- Benchmark Memory Monitor ---
        print("\n[3] MemoryMonitor.sample() — 100 iterations")
        let memStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 { _ = memoryMonitor.sample() }
        let memElapsed = CFAbsoluteTimeGetCurrent() - memStart
        let lastMem = memoryMonitor.sample()
        print("    Total: \(String(format: "%.3f", memElapsed))s")
        print("    Avg per call: \(String(format: "%.3f", memElapsed / 100.0 * 1000))ms")
        print("    Memory: \(ByteCountFormatter.humanReadable(lastMem.usedBytes)) / \(ByteCountFormatter.humanReadable(lastMem.totalBytes))")

        // --- Benchmark Disk Monitor ---
        print("\n[4] DiskMonitor.sample() — 100 iterations")
        let diskStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 { _ = diskMonitor.sample() }
        let diskElapsed = CFAbsoluteTimeGetCurrent() - diskStart
        print("    Total: \(String(format: "%.3f", diskElapsed))s")
        print("    Avg per call: \(String(format: "%.3f", diskElapsed / 100.0 * 1000))ms")

        // --- Benchmark Network Monitor ---
        print("\n[5] NetworkMonitor.sample() — 100 iterations")
        let netStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 { _ = networkMonitor.sample() }
        let netElapsed = CFAbsoluteTimeGetCurrent() - netStart
        print("    Total: \(String(format: "%.3f", netElapsed))s")
        print("    Avg per call: \(String(format: "%.3f", netElapsed / 100.0 * 1000))ms")

        // --- Benchmark sort + filter (simulate UI refresh) ---
        print("\n[6] Sort + Filter simulation — 100 iterations")
        let processes = processMonitor.sample()
        let sortStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            var filtered = processes.filter { $0.name.lowercased().contains("a") }
            filtered.sort { $0.cpuUsage > $1.cpuUsage }
            _ = filtered.count
        }
        let sortElapsed = CFAbsoluteTimeGetCurrent() - sortStart
        print("    Total: \(String(format: "%.3f", sortElapsed))s")
        print("    Avg per call: \(String(format: "%.3f", sortElapsed / 100.0 * 1000))ms")
        print("    Sorting \(processes.count) processes")

        // --- Memory footprint ---
        print("\n[7] Memory footprint")
        var rusage = rusage()
        getrusage(RUSAGE_SELF, &rusage)
        let rssKB = rusage.ru_maxrss / 1024
        print("    Peak RSS: \(rssKB) KB (\(String(format: "%.1f", Double(rssKB) / 1024.0)) MB)")

        // --- UID cache effectiveness ---
        print("\n[8] UID cache test")
        let cacheStart = CFAbsoluteTimeGetCurrent()
        _ = processMonitor.sample()
        let firstCall = CFAbsoluteTimeGetCurrent() - cacheStart
        let cacheStart2 = CFAbsoluteTimeGetCurrent()
        _ = processMonitor.sample()
        let secondCall = CFAbsoluteTimeGetCurrent() - cacheStart2
        print("    1st call (cold cache): \(String(format: "%.1f", firstCall * 1000))ms")
        print("    2nd call (warm cache): \(String(format: "%.1f", secondCall * 1000))ms")
        if firstCall > 0 {
            print("    Speedup: \(String(format: "%.1fx", firstCall / max(secondCall, 0.0001)))")
        }

        // --- Summary ---
        let totalRefreshTime = procElapsed / 10.0 + cpuElapsed / 100.0 + memElapsed / 100.0 + netElapsed / 100.0
        print("\n=== Summary ===")
        print("Estimated full refresh cycle: \(String(format: "%.1f", totalRefreshTime * 1000))ms")
        print("Process refresh interval: 2000ms → headroom: \(String(format: "%.0f", (2.0 - totalRefreshTime) / 2.0 * 100))%")
        print("Performance refresh interval: 1000ms → headroom: \(String(format: "%.0f", (1.0 - (cpuElapsed/100 + memElapsed/100 + netElapsed/100)) / 1.0 * 100))%")
        print("Peak memory: \(String(format: "%.1f", Double(rssKB) / 1024.0)) MB")
    }
}
