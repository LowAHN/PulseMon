import AppKit

@main
struct PulseMonEntry {
    static func main() {
        if CommandLine.arguments.contains("--benchmark") {
            Benchmark.run()
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
