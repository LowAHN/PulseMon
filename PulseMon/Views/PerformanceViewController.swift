import AppKit

// MARK: - Line Graph View

final class LineGraphView: NSView {
    var dataPoints: [Double] = [] { didSet { needsDisplay = true } }
    var maxValue: Double = 100
    var lineColor: NSColor = .systemBlue { didSet { _valueAttrs = nil } }
    var fillColor: NSColor = NSColor.systemBlue.withAlphaComponent(0.15)
    var title: String = ""
    var valueText: String = "" { didSet { if valueText != oldValue { needsDisplay = true } } }
    var maxPoints: Int = 60

    // Cached label attributes
    private static let titleAttrs: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.labelColor,
        .font: NSFont.systemFont(ofSize: 12, weight: .medium),
    ]
    private static let timeAttrs: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.secondaryLabelColor,
        .font: NSFont.systemFont(ofSize: 9),
    ]
    private var _valueAttrs: [NSAttributedString.Key: Any]?
    private var valueAttrs: [NSAttributedString.Key: Any] {
        if let cached = _valueAttrs { return cached }
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: lineColor,
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
        ]
        _valueAttrs = attrs
        return attrs
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bg = NSColor(white: 0.12, alpha: 1.0)
        bg.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

        // Border
        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        border.lineWidth = 0.5
        border.stroke()

        let graphInset = NSEdgeInsets(top: 30, left: 8, bottom: 24, right: 8)
        let graphRect = NSRect(
            x: bounds.minX + graphInset.left,
            y: bounds.minY + graphInset.bottom,
            width: bounds.width - graphInset.left - graphInset.right,
            height: bounds.height - graphInset.top - graphInset.bottom
        )

        // Grid lines
        NSColor(white: 0.25, alpha: 1.0).setStroke()
        for i in 1..<4 {
            let y = graphRect.minY + graphRect.height * CGFloat(i) / 4.0
            let line = NSBezierPath()
            line.move(to: NSPoint(x: graphRect.minX, y: y))
            line.line(to: NSPoint(x: graphRect.maxX, y: y))
            line.lineWidth = 0.5
            line.stroke()
        }

        // Data line
        guard dataPoints.count >= 2 else { return drawLabels(in: graphRect) }

        let path = NSBezierPath()
        let fillPath = NSBezierPath()
        let count = dataPoints.count
        let step = graphRect.width / CGFloat(maxPoints - 1)

        let startX = graphRect.maxX - CGFloat(count - 1) * step

        fillPath.move(to: NSPoint(x: startX, y: graphRect.minY))

        for (i, value) in dataPoints.enumerated() {
            let x = startX + CGFloat(i) * step
            let normalized = min(value / maxValue, 1.0)
            let y = graphRect.minY + graphRect.height * CGFloat(normalized)
            let point = NSPoint(x: x, y: y)

            if i == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
            fillPath.line(to: point)
        }

        // Fill under curve
        let lastX = startX + CGFloat(count - 1) * step
        fillPath.line(to: NSPoint(x: lastX, y: graphRect.minY))
        fillPath.close()
        fillColor.setFill()
        fillPath.fill()

        // Stroke line
        lineColor.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        drawLabels(in: graphRect)
    }

    private func drawLabels(in graphRect: NSRect) {
        let titleStr = NSAttributedString(string: title, attributes: Self.titleAttrs)
        titleStr.draw(at: NSPoint(x: bounds.minX + 8, y: bounds.maxY - 22))

        let valueStr = NSAttributedString(string: valueText, attributes: valueAttrs)
        let valueSize = valueStr.size()
        valueStr.draw(at: NSPoint(x: bounds.maxX - valueSize.width - 8, y: bounds.maxY - 22))

        let timeStr = NSAttributedString(string: "60 seconds", attributes: Self.timeAttrs)
        timeStr.draw(at: NSPoint(x: bounds.minX + 8, y: bounds.minY + 4))
    }
}

// MARK: - Performance View Controller

final class PerformanceViewController: NSViewController {

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let diskMonitor = DiskMonitor()
    private let networkMonitor = NetworkMonitor()

    private let cpuGraph = LineGraphView()
    private let memoryGraph = LineGraphView()
    private let networkUpGraph = LineGraphView()
    private let networkDownGraph = LineGraphView()

    private var cpuHistory: [Double] = []
    private var memoryHistory: [Double] = []
    private var netUpHistory: [Double] = []
    private var netDownHistory: [Double] = []
    private var peakNetUp: UInt64 = 1024
    private var peakNetDown: UInt64 = 1024

    private let diskLabel = NSTextField(labelWithString: "")
    private var timer: Timer?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 560))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGraphs()
        // Prime the monitors
        _ = cpuMonitor.sample()
        _ = networkMonitor.sample()
        startTimer()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        timer?.invalidate()
        timer = nil
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if timer == nil { startTimer() }
    }

    private func setupGraphs() {
        cpuGraph.title = "CPU Usage"
        cpuGraph.lineColor = .systemGreen
        cpuGraph.fillColor = NSColor.systemGreen.withAlphaComponent(0.15)

        memoryGraph.title = "Memory Usage"
        memoryGraph.lineColor = .systemBlue
        memoryGraph.fillColor = NSColor.systemBlue.withAlphaComponent(0.15)

        networkUpGraph.title = "Network Upload"
        networkUpGraph.lineColor = .systemOrange
        networkUpGraph.fillColor = NSColor.systemOrange.withAlphaComponent(0.15)

        networkDownGraph.title = "Network Download"
        networkDownGraph.lineColor = .systemPurple
        networkDownGraph.fillColor = NSColor.systemPurple.withAlphaComponent(0.15)

        diskLabel.font = NSFont.systemFont(ofSize: 12)
        diskLabel.textColor = .secondaryLabelColor

        let graphs = [cpuGraph, memoryGraph, networkUpGraph, networkDownGraph]
        for g in graphs {
            g.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(g)
        }

        diskLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(diskLabel)

        let padding: CGFloat = 12
        let spacing: CGFloat = 8

        NSLayoutConstraint.activate([
            // CPU - top left
            cpuGraph.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            cpuGraph.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            cpuGraph.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -spacing / 2),
            cpuGraph.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.42),

            // Memory - top right
            memoryGraph.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            memoryGraph.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: spacing / 2),
            memoryGraph.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            memoryGraph.heightAnchor.constraint(equalTo: cpuGraph.heightAnchor),

            // Network Up - bottom left
            networkUpGraph.topAnchor.constraint(equalTo: cpuGraph.bottomAnchor, constant: spacing),
            networkUpGraph.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            networkUpGraph.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -spacing / 2),
            networkUpGraph.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.35),

            // Network Down - bottom right
            networkDownGraph.topAnchor.constraint(equalTo: memoryGraph.bottomAnchor, constant: spacing),
            networkDownGraph.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: spacing / 2),
            networkDownGraph.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            networkDownGraph.heightAnchor.constraint(equalTo: networkUpGraph.heightAnchor),

            // Disk label
            diskLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            diskLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
        ])
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }

    private func updateMetrics() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let cpu = self.cpuMonitor.sample()
            let mem = self.memoryMonitor.sample()
            let disk = self.diskMonitor.sample()
            let net = self.networkMonitor.sample()

            DispatchQueue.main.async {
                self.updateCPU(cpu)
                self.updateMemory(mem)
                self.updateDisk(disk)
                self.updateNetwork(net)
            }
        }
    }

    private func updateCPU(_ m: CPUMetrics) {
        cpuHistory.append(m.totalUsage)
        if cpuHistory.count > 60 { cpuHistory.removeFirst() }
        cpuGraph.dataPoints = cpuHistory
        cpuGraph.valueText = String(format: "%.1f%%", m.totalUsage)
    }

    private func updateMemory(_ m: MemoryMetrics) {
        memoryHistory.append(m.usagePercent)
        if memoryHistory.count > 60 { memoryHistory.removeFirst() }
        memoryGraph.dataPoints = memoryHistory
        let used = ByteCountFormatter.humanReadable(m.usedBytes)
        let total = ByteCountFormatter.humanReadable(m.totalBytes)
        memoryGraph.valueText = "\(used) / \(total)"
    }

    private func updateDisk(_ m: DiskMetrics) {
        let used = ByteCountFormatter.humanReadable(m.usedBytes)
        let total = ByteCountFormatter.humanReadable(m.totalBytes)
        let free = ByteCountFormatter.humanReadable(m.freeBytes)
        diskLabel.stringValue = "Disk: \(used) used / \(total) total (\(free) free)"
    }

    private func updateNetwork(_ m: NetworkMetrics) {
        peakNetUp = max(peakNetUp, max(m.uploadBytesPerSecond, 1024))
        peakNetDown = max(peakNetDown, max(m.downloadBytesPerSecond, 1024))

        netUpHistory.append(Double(m.uploadBytesPerSecond))
        if netUpHistory.count > 60 { netUpHistory.removeFirst() }
        networkUpGraph.maxValue = Double(peakNetUp) * 1.2
        networkUpGraph.dataPoints = netUpHistory
        networkUpGraph.valueText = ByteCountFormatter.shortRate(m.uploadBytesPerSecond)

        netDownHistory.append(Double(m.downloadBytesPerSecond))
        if netDownHistory.count > 60 { netDownHistory.removeFirst() }
        networkDownGraph.maxValue = Double(peakNetDown) * 1.2
        networkDownGraph.dataPoints = netDownHistory
        networkDownGraph.valueText = ByteCountFormatter.shortRate(m.downloadBytesPerSecond)
    }
}
