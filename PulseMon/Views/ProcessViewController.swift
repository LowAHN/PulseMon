import AppKit

final class ProcessViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSMenuDelegate {

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let searchField = NSSearchField()
    private let statusLabel = NSTextField(labelWithString: "")

    private let processMonitor = ProcessMonitor()
    private var allProcesses: [ProcessEntry] = []
    private var filteredProcesses: [ProcessEntry] = []
    private var searchQuery: String = ""
    private var timer: Timer?

    private var sortKey: String = "cpu"
    private var sortAscending: Bool = false

    private let columns: [(id: String, title: String, width: CGFloat)] = [
        ("name",   "Name",     200),
        ("pid",    "PID",       60),
        ("cpu",    "CPU %",     70),
        ("memory", "Memory",    80),
        ("user",   "User",     100),
        ("status", "Status",    80),
    ]

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 560))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSearchField()
        setupTableView()
        setupStatusLabel()
        refresh()
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

    // MARK: - Setup

    private func setupSearchField() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search processes (⌘F)"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        view.addSubview(searchField)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            searchField.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func setupTableView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        view.addSubview(scrollView)

        for col in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(col.id))
            column.title = col.title
            column.width = col.width
            column.minWidth = 40
            column.sortDescriptorPrototype = NSSortDescriptor(key: col.id, ascending: true)
            tableView.addTableColumn(column)
        }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.style = .fullWidth

        // Context menu
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Terminate Process", action: #selector(terminateProcess(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Force Kill Process", action: #selector(forceKillProcess(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Copy PID", action: #selector(copyPID(_:)), keyEquivalent: ""))
        tableView.menu = menu

        scrollView.documentView = tableView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
        ])
    }

    private func setupStatusLabel() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            statusLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let processes = self.processMonitor.sample()
            DispatchQueue.main.async {
                self.allProcesses = processes
                self.applyFilterAndSort()
            }
        }
    }

    private func applyFilterAndSort() {
        let oldFiltered = filteredProcesses
        if searchQuery.isEmpty {
            filteredProcesses = allProcesses
        } else {
            let q = searchQuery.lowercased()
            filteredProcesses = allProcesses.filter {
                $0.name.lowercased().contains(q) || "\($0.pid)".contains(q)
            }
        }

        filteredProcesses.sort { a, b in
            let result: Bool
            switch sortKey {
            case "name":   result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case "pid":    result = a.pid < b.pid
            case "cpu":    result = a.cpuUsage < b.cpuUsage
            case "memory": result = a.memoryBytes < b.memoryBytes
            case "user":   result = a.user < b.user
            case "status": result = a.status < b.status
            default:       result = a.cpuUsage < b.cpuUsage
            }
            return sortAscending ? result : !result
        }

        statusLabel.stringValue = "Processes: \(filteredProcesses.count) / \(allProcesses.count)"

        // Preserve selection across reload
        let selectedPid: pid_t?
        let currentRow = tableView.selectedRow
        if currentRow >= 0, currentRow < oldFiltered.count {
            selectedPid = oldFiltered[currentRow].pid
        } else {
            selectedPid = nil
        }

        tableView.reloadData()

        if let pid = selectedPid,
           let newRow = filteredProcesses.firstIndex(where: { $0.pid == pid }) {
            tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        }
    }

    // MARK: - Search

    @objc private func searchChanged(_ sender: NSSearchField) {
        searchQuery = sender.stringValue
        applyFilterAndSort()
    }

    func focusSearch() {
        view.window?.makeFirstResponder(searchField)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredProcesses.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnId = tableColumn?.identifier.rawValue, row < filteredProcesses.count else { return nil }
        let proc = filteredProcesses[row]

        let cellId = NSUserInterfaceItemIdentifier("Cell_\(columnId)")
        let cell: NSTextField
        if let existing = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTextField {
            cell = existing
        } else {
            cell = NSTextField(labelWithString: "")
            cell.identifier = cellId
            cell.lineBreakMode = .byTruncatingTail
            cell.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        }

        switch columnId {
        case "name":   cell.stringValue = proc.name
        case "pid":    cell.stringValue = "\(proc.pid)"
        case "cpu":    cell.stringValue = String(format: "%.1f", proc.cpuUsage)
        case "memory": cell.stringValue = ByteCountFormatter.humanReadable(proc.memoryBytes)
        case "user":   cell.stringValue = proc.user
        case "status": cell.stringValue = proc.status
        default:       cell.stringValue = ""
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let descriptor = tableView.sortDescriptors.first, let key = descriptor.key else { return }
        sortKey = key
        sortAscending = descriptor.ascending
        applyFilterAndSort()
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 22 }

    // MARK: - Context Menu Actions

    private func selectedProcess() -> ProcessEntry? {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < filteredProcesses.count else { return nil }
        return filteredProcesses[row]
    }

    @objc private func terminateProcess(_ sender: Any?) {
        guard let proc = selectedProcess() else { return }
        confirmAndKill(proc: proc, force: false)
    }

    @objc private func forceKillProcess(_ sender: Any?) {
        guard let proc = selectedProcess() else { return }
        confirmAndKill(proc: proc, force: true)
    }

    @objc private func copyPID(_ sender: Any?) {
        guard let proc = selectedProcess() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(proc.pid)", forType: .string)
    }

    private func confirmAndKill(proc: ProcessEntry, force: Bool) {
        let action = force ? "force kill" : "terminate"
        let alert = NSAlert()
        alert.messageText = "Are you sure?"
        alert.informativeText = "Do you want to \(action) \"\(proc.name)\" (PID \(proc.pid))?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: force ? "Force Kill" : "Terminate")
        alert.addButton(withTitle: "Cancel")

        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let success = self?.processMonitor.terminateProcess(pid: proc.pid, force: force) ?? false
            if !success {
                let err = NSAlert()
                err.messageText = "Failed to \(action) process"
                err.informativeText = "Permission denied. You may need to run as root to terminate this process."
                err.alertStyle = .critical
                err.runModal()
            }
            self?.refresh()
        }
    }

    func deleteSelectedProcess() {
        guard let proc = selectedProcess() else { return }
        confirmAndKill(proc: proc, force: false)
    }
}
