import AppKit

/// One small window shown while the Accessibility permission is missing: what the app does,
/// why it needs the permission, a button to grant it, and a status that flips to "Allowed"
/// by itself once macOS reports the grant.
@MainActor
final class WelcomeWindow: NSObject {
    private let permission: Permission
    private let window: NSWindow
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let stepsLabel = NSTextField(wrappingLabelWithString: "")
    private let statusIcon = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let settingsButton = NSButton()
    private let doneButton = NSButton()
    private var askedMacOS = false
    private var placed = false

    init(permission: Permission) {
        self.permission = permission
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "Close in Mission Control"
        window.isReleasedWhenClosed = false
        build()
        update(granted: permission.isGranted)
    }

    func show() {
        update(granted: permission.isGranted)
        if !placed {
            window.center()
            placed = true
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Call when the permission changes. A visible window is brought forward so the user,
    /// who is probably in System Settings, sees "Allowed" appear.
    func permissionChanged(granted: Bool) {
        Log.write("accessibility \(granted ? "granted" : "revoked"); welcome window visible: \(window.isVisible)")
        update(granted: granted)
        guard granted else { return show() }
        guard window.isVisible else { return }
        // Since macOS 14 an app cannot pull itself in front of System Settings, which is
        // where the user is. Float above it for a few seconds so "Allowed" is seen.
        window.level = .floating
        NSApp.activate()
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            MainActor.assumeIsolated { self.window.level = .normal }
        }
    }

    // MARK: - Layout

    private func symbol(_ name: String, size: CGFloat = 20) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }

    private func build() {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 72),
            icon.heightAnchor.constraint(equalToConstant: 72),
        ])

        let title = NSTextField(labelWithString: "Welcome to Close in Mission Control")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        subtitleLabel.textColor = .secondaryLabelColor

        let permissionIcon = NSImageView(image: symbol("accessibility", size: 24) ?? NSImage())
        permissionIcon.contentTintColor = .secondaryLabelColor
        permissionIcon.setContentHuggingPriority(.required, for: .horizontal)

        let name = NSTextField(labelWithString: "Accessibility")
        name.font = .systemFont(ofSize: 13, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString:
            "So the app can find the window thumbnails in Mission Control and press a window's own "
            + "close button. Nothing is recorded, and nothing leaves your Mac.")
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        let text = NSStackView(views: [name, detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        let status = NSStackView(views: [statusIcon, statusLabel])
        status.spacing = 5
        status.setContentHuggingPriority(.required, for: .horizontal)
        status.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = NSStackView(views: [permissionIcon, text, status])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let card = CardView()
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            // The card is 424 wide: 14 + icon 24 + 12 + text + 12 + status ~110 + 14.
            text.widthAnchor.constraint(equalToConstant: 232),
        ])
        detail.preferredMaxLayoutWidth = 232

        let steps = stepsLabel
        steps.font = .systemFont(ofSize: 12)
        steps.textColor = .secondaryLabelColor

        settingsButton.title = "Open Accessibility Settings"
        settingsButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        doneButton.title = "Done"
        doneButton.bezelStyle = .rounded
        doneButton.target = self
        doneButton.action = #selector(done)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [settingsButton, spacer, doneButton])
        buttons.orientation = .horizontal

        let header = NSStackView(views: [icon, title, subtitleLabel])
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = 6
        header.setCustomSpacing(12, after: icon)

        let content = NSStackView(views: [header, card, steps, buttons])
        content.orientation = .vertical
        content.alignment = .centerX
        content.spacing = 18
        content.setCustomSpacing(22, after: header)
        content.edgeInsets = NSEdgeInsets(top: 28, left: 28, bottom: 24, right: 28)
        content.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            content.topAnchor.constraint(equalTo: root.topAnchor),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            root.widthAnchor.constraint(equalToConstant: 480),
            card.widthAnchor.constraint(equalToConstant: 424),
            steps.widthAnchor.constraint(equalToConstant: 424),
            buttons.widthAnchor.constraint(equalToConstant: 424),
        ])
        window.contentView = root
    }

    private func update(granted: Bool) {
        statusLabel.stringValue = granted ? "Allowed" : "Not allowed yet"
        statusLabel.textColor = granted ? .systemGreen : .secondaryLabelColor
        statusIcon.image = symbol(granted ? "checkmark.circle.fill" : "circle", size: 15)
        statusIcon.contentTintColor = granted ? .systemGreen : .tertiaryLabelColor
        settingsButton.isHidden = granted
        settingsButton.keyEquivalent = granted ? "" : "\r"
        doneButton.isEnabled = granted
        doneButton.keyEquivalent = granted ? "\r" : ""
        subtitleLabel.stringValue = granted ? "You're all set. It runs from the menu bar." : "One permission, then you're set."
        stepsLabel.stringValue = granted
            ? "Open Mission Control and hover over a window: a small × appears on its top-left corner. "
                + "Click the × icon in the menu bar to turn on Launch at Login or to quit."
            : "Then open Mission Control and hover over a window. A small × appears on its top-left corner. "
                + "Quit any time from the × icon in the menu bar."
        fitWindowToContent()
    }

    /// The wording changes with the state, so keep the window as tall as its content,
    /// holding the top edge still.
    private func fitWindowToContent() {
        guard let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let height = content.fittingSize.height
        guard height > 0, abs(window.contentLayoutRect.height - height) > 0.5 else { return }
        var frame = window.frame
        let newFrame = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 480, height: height))
        frame.origin.y += frame.height - newFrame.height
        frame.size.height = newFrame.height
        window.setFrame(frame, display: true)
    }

    // MARK: - Actions

    @objc private func openSettings() {
        // The first press asks macOS, which lists the app under Accessibility and shows a
        // prompt with its own "Open System Settings" button. After that, go straight there.
        if askedMacOS {
            permission.openSettings()
        } else {
            askedMacOS = true
            permission.showSystemPrompt()
        }
    }

    @objc private func done() {
        window.close()
    }
}

/// The rounded grey panel behind the permission row. Its colour follows light and dark mode.
private final class CardView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
        }
    }
}
