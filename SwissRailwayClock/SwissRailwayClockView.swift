import ScreenSaver
import CoreGraphics

class SwissRailwayClockView: ScreenSaverView {

    private var clockRenderer: ClockRenderer!
    private var clockAnimator: ClockAnimator!
    private var shouldShowClock: Bool?
    private var frameCount: Int = 0
    private let detectionDelay: Int = 60  // Wait ~2 seconds at 30fps before detecting display

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
        clockAnimator.start()
    }

    override func stopAnimation() {
        super.stopAnimation()
        clockAnimator.stop()
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
