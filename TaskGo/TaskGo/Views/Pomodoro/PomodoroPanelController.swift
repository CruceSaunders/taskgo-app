import AppKit
import SwiftUI
import Combine

class PomodoroPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private var pomodoroVM: PomodoroViewModel?

    private let panelWidth: CGFloat = 220
    private let panelHeight: CGFloat = 280

    override init() {
        super.init()
        setupNotifications()
    }

    func setViewModel(_ viewModel: PomodoroViewModel) {
        self.pomodoroVM = viewModel
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .pomodoroShowPanel)
            .sink { [weak self] _ in self?.show() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .pomodoroHidePanel)
            .sink { [weak self] _ in self?.close() }
            .store(in: &cancellables)
    }

    func show() {
        if panel == nil {
            createPanel()
        }
        panel?.orderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func createPanel() {
        let savedX = UserDefaults.standard.double(forKey: "pomodoroPanelX")
        let savedY = UserDefaults.standard.double(forKey: "pomodoroPanelY")

        let frame: NSRect
        if savedX != 0 || savedY != 0 {
            frame = NSRect(x: savedX, y: savedY, width: panelWidth, height: panelHeight)
        } else {
            guard let screen = NSScreen.main else { return }
            let screenFrame = screen.visibleFrame
            frame = NSRect(
                x: screenFrame.maxX - panelWidth - 20,
                y: screenFrame.maxY - panelHeight - 80,
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
        panel.delegate = self

        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: panel)
            .sink { [weak panel] _ in
                guard let panel = panel else { return }
                UserDefaults.standard.set(panel.frame.origin.x, forKey: "pomodoroPanelX")
                UserDefaults.standard.set(panel.frame.origin.y, forKey: "pomodoroPanelY")
            }
            .store(in: &cancellables)

        let content: AnyView
        if let vm = pomodoroVM {
            content = AnyView(PomodoroWidgetView().environmentObject(vm))
        } else {
            content = AnyView(Text("Loading..."))
        }
        panel.contentView = NSHostingView(rootView: content)
        self.panel = panel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor in
            pomodoroVM?.stop()
        }
        return false
    }
}
