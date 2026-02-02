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
    private var watchdogTimer: Timer?
    private var lastAnimationTime: Date?
    private var isFullScreenMode = false  // True only when running as actual screensaver

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

        // Listen for system screensaver stop notifications
        // willstop fires BEFORE the screensaver stops - gives us time to clean up
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenSaverWillStop),
            name: NSNotification.Name("com.apple.screensaver.willstop"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenSaverDidStop),
            name: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil
        )

        // Note: Watchdog timer is started later in startAnimation() after we can
        // detect if we're in full-screen mode vs preview in System Settings
    }

    private func startWatchdogTimer() {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.watchdogCheck()
        }
    }

    @objc private func watchdogCheck() {
        // Skip checks if we haven't started or not in full-screen mode
        guard hasStartedAnimation, isFullScreenMode else { return }

        var shouldExit = false

        // Check 1: If animation hasn't run in 5 seconds, we're likely orphaned
        if let lastTime = lastAnimationTime, Date().timeIntervalSince(lastTime) > 5.0 {
            shouldExit = true
        }

        // Check 2: Window is no longer visible or doesn't exist
        if self.window == nil {
            shouldExit = true
        } else if let window = self.window {
            // Check 3: Window is not visible on any screen
            if !window.isVisible || window.occlusionState.contains(.visible) == false {
                shouldExit = true
            }

            // Check 4: Window alpha is zero (invisible)
            if window.alphaValue <= 0 {
                shouldExit = true
            }
        }

        if shouldExit {
            // In full-screen mode, force exit as last resort
            // (normal teardown via notifications should have already happened)
            cleanupAndExit()
        }
    }

    @objc private func screenSaverWillStop(_ notification: Notification) {
        // System notified that screensaver is about to stop
        // On macOS 14.0+ (Sonoma), perform cleanup to prevent lingering process
        if #available(macOS 14.0, *) {
            teardown()
        }
    }

    @objc private func screenSaverDidStop(_ notification: Notification) {
        // System notified that screensaver stopped
        // On macOS 14.0+ (Sonoma), ensure cleanup happened
        if #available(macOS 14.0, *) {
            teardown()
        }
    }

    /// Clean up resources to allow process to exit naturally (Sonoma fix)
    private func teardown() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        clockAnimator.stop()

        // Clear cached resources
        clockRenderer = nil

        // Remove from view hierarchy
        self.removeFromSuperview()
    }

    @objc private func applicationWillTerminate(_ notification: Notification) {
        cleanupAndExit()
    }

    @objc private func windowWillClose(_ notification: Notification) {
        // Respond to our own window closing
        if let closingWindow = notification.object as? NSWindow,
           closingWindow == self.window {
            if #available(macOS 14.0, *) {
                teardown()
            }
        }
    }

    /// Force exit - only used by watchdog when normal cleanup doesn't work
    private func cleanupAndExit() {
        teardown()
        // Force exit as last resort when process won't terminate naturally
        exit(0)
    }

    deinit {
        watchdogTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
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

    /// Determines if we're running as actual full-screen screensaver (not preview in Settings)
    private func detectFullScreenMode() -> Bool {
        guard let window = self.window, let screen = window.screen else {
            return false
        }

        // Check if window covers the entire screen (full-screen screensaver)
        let windowFrame = window.frame
        let screenFrame = screen.frame

        // Allow small tolerance for frame comparison
        let tolerance: CGFloat = 10
        let coversScreen = abs(windowFrame.width - screenFrame.width) < tolerance &&
                          abs(windowFrame.height - screenFrame.height) < tolerance

        // Also check window level - screensaver windows have a high level
        let hasScreenSaverLevel = window.level.rawValue >= NSWindow.Level.screenSaver.rawValue

        return coversScreen && hasScreenSaverLevel
    }

    // MARK: - ScreenSaverView Lifecycle

    override func startAnimation() {
        super.startAnimation()
        hasStartedAnimation = true
        stopAnimationCalled = false
        clockAnimator.start()

        // Detect full-screen mode after a short delay (window needs to be set up)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.isFullScreenMode = self.detectFullScreenMode()

            // Only start watchdog for actual full-screen screensaver
            if self.isFullScreenMode {
                self.startWatchdogTimer()
            }
        }
    }

    override func stopAnimation() {
        super.stopAnimation()
        stopAnimationCalled = true
        clockAnimator.stop()

        // On macOS 14.0+ (Sonoma), perform cleanup to help process exit
        if #available(macOS 14.0, *) {
            teardown()
        }
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
        // Track animation timing for watchdog
        lastAnimationTime = Date()

        // Check if we should clean up (Sonoma bug workaround)
        if hasStartedAnimation {
            // Check if window is gone or view is hidden
            if window == nil || isHiddenOrHasHiddenAncestor {
                if #available(macOS 14.0, *) {
                    teardown()
                }
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
