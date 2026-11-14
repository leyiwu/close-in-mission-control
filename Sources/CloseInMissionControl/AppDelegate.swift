import AppKit
import CloseInMissionControlCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permission = Permission()
    private var welcomeWindow: WelcomeWindow?
    /// Made on first use and made again when the language changes, since its text is set
    /// when it is built.
    private var welcome: WelcomeWindow {
        if let existing = welcomeWindow { return existing }
        let created = WelcomeWindow(permission: permission)
        welcomeWindow = created
        return created
    }
    private let version = VersionInfo(infoDictionary: Bundle.main.infoDictionary)
    private lazy var controller = Controller(isPermitted: { [permission] in permission.isGranted })
    private var statusItem: NSStatusItem!
    private let permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let grantItem = NSMenuItem(title: "", action: #selector(showWelcome), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let languageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let versionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let notesItem = NSMenuItem(title: "", action: #selector(openReleaseNotes), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    /// "Follow System" first, then one item per language.
    private var languageChoices: [NSMenuItem] = []
    private let dumpItem = NSMenuItem(title: "Dump Mission Control AX Tree in 5 s", action: #selector(dumpSoon), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Close in Mission Control")
        statusItem.menu = buildMenu()

        permission.onChange = { [weak self] granted in
            self?.refreshMenu()
            self?.welcome.permissionChanged(granted: granted)
        }
        refreshMenu()
        Log.write("version \(version.logSummary)")
        controller.start()
        permission.startWatching()
        // Opening the app by hand shows the window, so a menu-bar app that otherwise stays
        // silent does not look like it failed to start. Starting at login stays quiet.
        // `--welcome` forces the window.
        let atLogin = launchedAtLogin()
        if !permission.isGranted || !atLogin || CommandLine.arguments.contains("--welcome") { welcome.show() }
    }

    /// Opening the app again while it is running (Finder, Spotlight, Launchpad).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        welcome.show()
        return false
    }

    /// True when macOS started the app as a login item. The launch event carries a marker
    /// for that; as a second signal, a login item that was enabled and a Mac that booted
    /// moments ago also counts. Both are logged so a wrong guess can be diagnosed.
    private func launchedAtLogin() -> Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let byEvent = event?.eventID == AEEventID(kAEOpenApplication)
            && event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
                == OSType(keyAELaunchedAsLogInItem)
        let enabled = SMAppService.mainApp.status == .enabled
        let uptime = ProcessInfo.processInfo.systemUptime
        Log.write("launch: login-item event=\(byEvent), launch-at-login on=\(enabled), uptime=\(Int(uptime))s")
        return byEvent || (enabled && uptime < 180)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        permissionItem.isEnabled = false
        menu.addItem(permissionItem)
        menu.addItem(grantItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)

        let languages = NSMenu()
        languages.autoenablesItems = false
        let followSystem = NSMenuItem(title: "", action: #selector(chooseLanguage(_:)), keyEquivalent: "")
        followSystem.representedObject = ""
        languageChoices = [followSystem]
        for language in LanguageChoice.available {
            let item = NSMenuItem(title: language.name, action: #selector(chooseLanguage(_:)), keyEquivalent: "")
            item.representedObject = language.code
            languageChoices.append(item)
        }
        languageChoices.forEach(languages.addItem)
        languageItem.submenu = languages
        menu.addItem(languageItem)

        let debug = NSMenu()
        debug.autoenablesItems = false
        debug.addItem(dumpItem)
        debug.addItem(NSMenuItem(title: "Show Welcome Window", action: #selector(showWelcome), keyEquivalent: ""))
        debug.addItem(NSMenuItem(title: "Open Logs Folder", action: #selector(openLogs), keyEquivalent: ""))
        let debugItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        debugItem.submenu = debug
        menu.addItem(debugItem)

        menu.addItem(.separator())
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(notesItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        for item in menu.items + debug.items + languageChoices where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        return menu
    }

    private func refreshMenu() {
        let granted = permission.isGranted
        permissionItem.title = granted
            ? tr("menu.accessibility.granted", "Accessibility: Granted")
            : tr("menu.accessibility.notGranted", "Accessibility: Not Granted")
        grantItem.isHidden = granted
        dumpItem.isEnabled = granted
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        // Everything below follows the chosen language, so this also runs after a change.
        grantItem.title = tr("menu.setUp", "Set Up Accessibility…")
        loginItem.title = tr("menu.launchAtLogin", "Launch at Login")
        languageItem.title = tr("menu.language", "Language")
        languageChoices.first?.title = tr("menu.language.system", "Follow System")
        let chosen = LanguageChoice.current ?? ""
        for item in languageChoices { item.state = (item.representedObject as? String) == chosen ? .on : .off }
        // The version is a small grey footer line rather than a full-size row.
        let versionTitle = version.menuTitle(versionWord: tr("menu.version", "Version"))
        versionItem.title = versionTitle
        versionItem.attributedTitle = NSAttributedString(string: versionTitle, attributes: [
            .font: NSFont.menuFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        notesItem.title = tr("menu.releaseNotes", "Release Notes…")
        quitItem.title = tr("menu.quit", "Quit")
    }

    @objc private func chooseLanguage(_ sender: NSMenuItem) {
        let code = sender.representedObject as? String ?? ""
        LanguageChoice.current = code.isEmpty ? nil : code
        Log.write("language: \(code.isEmpty ? "follow system" : code)")
        refreshMenu()
        // The welcome window's text is fixed when it is built, so build it again.
        let wasVisible = welcomeWindow?.isVisible ?? false
        welcomeWindow?.close()
        welcomeWindow = nil
        if wasVisible { welcome.show() }
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

    @objc private func showWelcome() { welcome.show() }

    @objc private func openReleaseNotes() { NSWorkspace.shared.open(version.releaseNotesURL) }

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
