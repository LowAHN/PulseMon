import AppKit

final class MainWindowController: NSWindowController, NSToolbarDelegate {

    private let tabViewController = NSTabViewController()
    let processVC = ProcessViewController()
    private let performanceVC = PerformanceViewController()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)

        window.title = "PulseMon"
        window.center()
        window.minSize = NSSize(width: 600, height: 400)
        window.setFrameAutosaveName("PulseMonMainWindow")

        setupTabs()
        window.contentViewController = tabViewController

        setupToolbar()
    }

    private func setupTabs() {
        let processTab = NSTabViewItem(viewController: processVC)
        processTab.label = "Processes"
        processTab.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Processes")

        let perfTab = NSTabViewItem(viewController: performanceVC)
        perfTab.label = "Performance"
        perfTab.image = NSImage(systemSymbolName: "chart.xyaxis.line", accessibilityDescription: "Performance")

        tabViewController.addTabViewItem(processTab)
        tabViewController.addTabViewItem(perfTab)
        tabViewController.tabStyle = .toolbar
    }

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        window?.toolbar = toolbar
    }

    // NSToolbarDelegate - minimal, tabs are managed by NSTabViewController
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        nil
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace]
    }
}
