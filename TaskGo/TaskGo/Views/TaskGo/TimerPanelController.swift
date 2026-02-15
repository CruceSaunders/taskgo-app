import AppKit
import SwiftUI
import Combine

/// Controls the floating NSPanel that displays the Task Go timer
class TimerPanelController {
    private var panel: NSPanel?
    private var bounceTimer: Timer?
    private var isBouncing = false
    private var originalFrame: NSRect?
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .taskGoShowPanel)
            .sink { [weak self] _ in
                self?.show()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .taskGoHidePanel)
            .sink { [weak self] _ in
                self?.close()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .taskGoTimerExpired)
            .sink { [weak self] _ in
                self?.startBouncing()
            }
            .store(in: &cancellables)
    }

    func show() {
        if panel == nil {
            createPanel()
        }
        panel?.orderFront(nil)
    }

    func close() {
        stopBouncing()
        panel?.orderOut(nil)
        panel = nil
    }

    private func createPanel() {
        // Restore saved position or use default (top-right)
        let savedX = UserDefaults.standard.double(forKey: "timerPanelX")
        let savedY = UserDefaults.standard.double(forKey: "timerPanelY")

        let panelWidth: CGFloat = 220
        let panelHeight: CGFloat = 120

        let frame: NSRect
        if savedX != 0 || savedY != 0 {
            frame = NSRect(x: savedX, y: savedY, width: panelWidth, height: panelHeight)
        } else {
            // Default: top-right of main screen
            guard let screen = NSScreen.main else { return }
            let screenFrame = screen.visibleFrame
            frame = NSRect(
                x: screenFrame.maxX - panelWidth - 20,
                y: screenFrame.maxY - panelHeight - 20,
                width: panelWidth,
                height: panelHeight
            )
        }

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        // Save position when moved
        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: panel)
            .sink { [weak panel] _ in
                guard let panel = panel else { return }
                UserDefaults.standard.set(panel.frame.origin.x, forKey: "timerPanelX")
                UserDefaults.standard.set(panel.frame.origin.y, forKey: "timerPanelY")
            }
            .store(in: &cancellables)

        let hostingView = NSHostingView(rootView: TimerWidgetView())
        panel.contentView = hostingView

        self.panel = panel
    }

    // MARK: - Bounce Animation

    func startBouncing() {
        guard !isBouncing else { return }
        isBouncing = true
        originalFrame = panel?.frame

        bounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.performBounce()
        }
    }

    func stopBouncing() {
        isBouncing = false
        bounceTimer?.invalidate()
        bounceTimer = nil

        // Restore original position
        if let original = originalFrame {
            panel?.setFrame(original, display: true, animate: true)
        }
    }

    private func performBounce() {
        guard let panel = panel, let original = originalFrame else { return }

        // Small bounce animation
        let bounceHeight: CGFloat = 6
        let bounceFrame = NSRect(
            x: original.origin.x + CGFloat.random(in: -2...2),
            y: original.origin.y + bounceHeight,
            width: original.width,
            height: original.height
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(bounceFrame, display: true)
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(original, display: true)
            })
        })
    }
}
