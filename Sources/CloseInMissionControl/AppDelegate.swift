import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permission = Permission()
    private lazy var controller = Controller(isPermitted: { [permission] in permission.isGranted })
    private var statusItem: NSStatusItem!
    private let permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let grantItem = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openSettings), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let dumpItem = NSMenuItem(title: "Dump Mission Control AX Tree in 5 s", action: #selector(dumpSoon), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Close in Mission Control")
        statusItem.menu = buildMenu()

        permission.onChange = { [weak self] _ in self?.refreshMenu() }
        refreshMenu()
        controller.start()
        permission.requestIfNeeded()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        permissionItem.isEnabled = false
        menu.addItem(permissionItem)
        menu.addItem(grantItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)

        let debug = NSMenu()
        debug.autoenablesItems = false
        debug.addItem(dumpItem)
        debug.addItem(NSMenuItem(title: "Open Logs Folder", action: #selector(openLogs), keyEquivalent: ""))
        let debugItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        debugItem.submenu = debug
        menu.addItem(debugItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Close in Mission Control", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items + debug.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        return menu
    }

    private func refreshMenu() {
        let granted = permission.isGranted
        permissionItem.title = granted ? "Accessibility: Granted" : "Accessibility: Not Granted"
        grantItem.isHidden = granted
        dumpItem.isEnabled = granted
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    /// The app's only setting. Off until the user turns it on; macOS lists it under
    /// System Settings → General → Login Items.
    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            Log.write("launch at login change failed: \(error.localizedDescription)")
            NSSound.beep()
        }
        refreshMenu()
    }

    @objc private func openSettings() { permission.openSettings() }

    @objc private func openLogs() {
        try? FileManager.default.createDirectory(at: Probe.logsFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Probe.logsFolder)
    }

    /// Delayed so you have time to open Mission Control and hover a window.
    @objc private func dumpSoon() {
        dumpItem.isEnabled = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            defer { self.refreshMenu() }
            do {
                if let file = try Probe.writeDump() {
                    NSSound(named: "Glass")?.play()
                    NSWorkspace.shared.activateFileViewerSelecting([file])
                } else {
                    NSSound.beep()
                }
            } catch {
                NSSound.beep()
                NSLog("CloseInMissionControl: dump failed: \(error)")
            }
        }
    }
}
