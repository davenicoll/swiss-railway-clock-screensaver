import ScreenSaver
import CoreGraphics

class SwissRailwayClockView: ScreenSaverView {

    private var clockRenderer: ClockRenderer!
    private var clockAnimator: ClockAnimator!
    private var shouldShowClock: Bool?
    private var frameCount: Int = 0
    private let detectionDelay: Int = 60  // Wait ~2 seconds at 30fps before detecting display

    // MARK: - Sonoma Exit Fix
    // macOS Sonoma has a bug where legacyScreenSaver doesn't exit properly,
    // causing high CPU/RAM usage. We track state to force exit when needed.
    private var hasStartedAnimation = false
    private var stopAnimationCalled = false

    // MARK: - Initialization

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // 30 FPS - sufficient for smooth second hand, halves CPU/GPU load
        animationTimeInterval = 1.0 / 30.0

        // Initialize components
        clockRenderer = ClockRenderer()
        clockAnimator = ClockAnimator()

        // Layer-backed for efficiency
        wantsLayer = true
        layer?.drawsAsynchronously = true

        // Register for notifications to detect when screensaver should exit
        // This helps work around macOS Sonoma's legacyScreenSaver bug
        setupTerminationObservers()
    }

    private func setupTerminationObservers() {
        let nc = NotificationCenter.default

        // Observe when the application is about to terminate
        nc.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )

        // Observe when our window is about to close
        nc.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    @objc private func applicationWillTerminate(_ notification: Notification) {
        cleanupAndExit()
    }

    @objc private func windowWillClose(_ notification: Notification) {
        // Only respond to our own window closing
        if let closingWindow = notification.object as? NSWindow,
           closingWindow == self.window {
            cleanupAndExit()
        }
    }

    private func cleanupAndExit() {
        clockAnimator.stop()
        // Force exit to work around Sonoma's legacyScreenSaver bug
        // where the process doesn't terminate properly
        exit(0)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func detectIfMainDisplay() -> Bool {
        guard let myScreen = window?.screen,
              let mainScreen = NSScreen.screens.first,
              let myID = myScreen.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID,
              let mainID = mainScreen.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID else {
            return true
        }
        return myID == mainID
    }

    // MARK: - ScreenSaverView Lifecycle

    override func startAnimation() {
        super.startAnimation()
        hasStartedAnimation = true
        stopAnimationCalled = false
        clockAnimator.start()
    }

    override func stopAnimation() {
        super.stopAnimation()
        stopAnimationCalled = true
        clockAnimator.stop()

        // Force exit to work around macOS Sonoma's legacyScreenSaver bug
        // Without this, the process continues running invisibly, consuming CPU/RAM
        cleanupAndExit()
    }

    override func draw(_ rect: NSRect) {
        // Always show clock in preview mode
        if isPreview {
            let timeState = clockAnimator.currentTimeState
            clockRenderer.draw(in: rect, timeState: timeState, isPreview: true)
            return
        }

        // Wait for display detection delay, then lock in the decision
        if shouldShowClock == nil {
            frameCount += 1
            if frameCount >= detectionDelay {
                shouldShowClock = detectIfMainDisplay()
            }
            // Show black while waiting for detection
            NSColor.black.setFill()
            rect.fill()
            return
        }

        if shouldShowClock == true {
            let timeState = clockAnimator.currentTimeState
            clockRenderer.draw(in: rect, timeState: timeState, isPreview: false)
        } else {
            NSColor.black.setFill()
            rect.fill()
        }
    }

    override func animateOneFrame() {
        // Check if we should exit (Sonoma bug workaround)
        // If animation started but view is no longer in a valid state, exit
        if hasStartedAnimation && !isPreview {
            // Check if window is gone or view is hidden
            if window == nil || isHiddenOrHasHiddenAncestor || !isDescendant(of: window?.contentView ?? self) {
                cleanupAndExit()
                return
            }
        }

        if clockAnimator.update() {
            setNeedsDisplay(bounds)
        }
    }

    // MARK: - Configuration (optional, no sheet for now)

    override var hasConfigureSheet: Bool {
        return false
    }

    override var configureSheet: NSWindow? {
        return nil
    }
}
