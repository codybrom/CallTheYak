import AppKit
import Combine

// Matches the original FCP4 state machine from _YakViewProc (field +0xE8)
enum YakAnimationState: Int {
    case idle = 0           // Hidden, waiting
    case grassGrowing = 1   // Grass patch appears (cells 0→3)
    case entering = 2       // Bruce appears at grass
    // 3 is unused in original
    case trotting = 4       // Normal trot across screen (cells 4-16)
    case triggeredTrot = 5  // From "Call the Yak" (sets talk flag)
    case preTalk = 6        // Bubble starts growing, no text
    case talking = 7        // Speech bubble with text visible
    case postTalk = 8       // Cycling quotes, continuing to graze
    case preExit = 9        // Transition before running
    case runningAway = 10   // Scared frames (cells 17-20), bolts right
}

final class YakManager: ObservableObject {
    static let shared = YakManager()

    // Rendering
    static let renderScale: CGFloat = 1.0
    static let scaledCellWidth: CGFloat = CGFloat(SpriteSheet.cellWidth) * renderScale
    static let scaledCellHeight: CGFloat = CGFloat(SpriteSheet.cellHeight) * renderScale

    // Mouse proximity threshold
    static let mouseProximity: CGFloat = 80.0

    // Movement speeds (in points per tick at 60fps)
    static let trotSpeed: CGFloat = 1.0
    static let scaredRunSpeed: CGFloat = 6.0

    @Published var state: YakAnimationState = .idle
    @Published var frameCounter: Int = 0
    @Published var bruceX: CGFloat = 0
    @Published var bruceFrame: Int = -1      // Current Bruce sprite cell (-1 = hidden)
    @Published var grassFrame: Int = -1      // Current grass sprite cell (-1 = hidden)
    @Published var poofFrame: Int = -1       // Current poof cloud frame (-1 = hidden)
    @Published var grassX: CGFloat = 0       // Where the grass patch is
    @Published var bubbleStage: Int = 0      // 0=hidden, 1-5=growing, 6+=with text
    @Published var currentQuote: String = ""
    @Published var isVisible: Bool = false
    @Published var talkFlag: Bool = false

    // User settings
    @Published var appearanceIntervalMinutes: Double {
        didSet {
            UserDefaults.standard.set(appearanceIntervalMinutes, forKey: "appearanceInterval")
            rescheduleRandomAppearance()
        }
    }

    var spriteSheet: SpriteSheet!
    var quotes: [String] = []
    private var quoteIndex: Int = 0

    private var randomAppearanceTimer: Timer?
    private var yakWindow: YakWindow?

    // Tick counter for sub-dividing the 60fps loop into slower animation rates
    private var tickCount: Int = 0

    private init() {
        self.appearanceIntervalMinutes = UserDefaults.standard.double(forKey: "appearanceInterval")
        if appearanceIntervalMinutes == 0 {
            appearanceIntervalMinutes = 30
        }
        loadResources()
        rescheduleRandomAppearance()
    }

    private func loadResources() {
        spriteSheet = SpriteSheet()
        if let url = Bundle.main.url(forResource: "Quotes", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let array = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] {
            quotes = array
        }
    }

    // MARK: - Public Actions

    func callTheYak() {
        talkFlag = true
        if state.rawValue < YakAnimationState.triggeredTrot.rawValue || state == .idle {
            startAppearance(triggered: true)
        }
    }

    func startAppearance(triggered: Bool = false) {
        guard !isVisible else {
            if triggered { talkFlag = true }
            return
        }
        isVisible = true
        state = .idle
        frameCounter = 0
        tickCount = 0
        bubbleStage = 0
        bruceFrame = -1
        grassFrame = -1
        poofFrame = -1
        bruceX = 0
        grassX = 0

        if triggered {
            talkFlag = true
            state = .triggeredTrot
        }

        showWindow()
    }

    func dismiss() {
        yakWindow?.orderOut(nil)
        isVisible = false
        state = .idle
        frameCounter = 0
        bruceFrame = -1
        grassFrame = -1
        poofFrame = -1
        bubbleStage = 0
        rescheduleRandomAppearance()
    }

    // MARK: - Window

    private func showWindow() {
        if yakWindow == nil {
            yakWindow = YakWindow(manager: self)
        }
        yakWindow?.showOnScreen()
    }

    // MARK: - Timers

    func rescheduleRandomAppearance() {
        randomAppearanceTimer?.invalidate()
        let intervalSeconds = appearanceIntervalMinutes * 60
        let jitter = intervalSeconds * 0.25
        let actual = intervalSeconds + Double.random(in: -jitter...jitter)
        randomAppearanceTimer = Timer.scheduledTimer(withTimeInterval: max(actual, 10), repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.startAppearance()
            }
        }
    }

    // Returns true every N ticks (for sub-dividing 60fps into slower rates)
    private func every(_ n: Int) -> Bool {
        return tickCount % n == 0
    }

    // MARK: - State Machine

    /// Called by YakScene.update() each frame
    func tick() {
        tickCount += 1
        checkMouseProximity()

        switch state {
        case .idle:
            tickIdle()
        case .grassGrowing:
            tickGrassGrowing()
        case .entering:
            tickEntering()
        case .trotting:
            tickTrotting()
        case .triggeredTrot:
            tickTriggeredTrot()
        case .preTalk:
            tickPreTalk()
        case .talking:
            tickTalking()
        case .postTalk:
            tickPostTalk()
        case .preExit:
            break // State 9 in original: immediately transitions to runningAway; handled by checkMouseProximity routing directly to .runningAway
        case .runningAway:
            tickRunningAway()
        }

    }

    // State 0: Wait before starting
    private func tickIdle() {
        // Advance every ~0.33s (20 ticks at 60fps)
        guard every(20) else { return }
        frameCounter += 1
        if frameCounter >= 6 {
            frameCounter = 0
            state = .grassGrowing
            if let screen = NSScreen.main {
                let screenW = screen.frame.width
                grassX = screenW * 0.7
                bruceX = screenW + Self.scaledCellWidth
            }
        }
    }

    // State 1: Grass poofs in — poof cloud (big→small), then grass appears
    private func tickGrassGrowing() {
        guard every(12) else { return }
        frameCounter += 1

        if frameCounter <= 5 {
            // Poof cloud: frames 0→4 (big→small)
            poofFrame = frameCounter - 1
            grassFrame = -1
        } else if frameCounter <= 6 {
            // Poof gone, grass appears
            poofFrame = -1
            grassFrame = 3
        } else {
            frameCounter = 0
            poofFrame = -1
            grassFrame = 3
            state = .entering
        }
    }

    // State 2: Bruce enters from right, walks toward grass
    private func tickEntering() {
        // Move every tick for smooth motion
        bruceX -= Self.trotSpeed

        // Advance trot frame every 4 ticks (~15fps sprite animation)
        if every(4) {
            frameCounter += 1
        }
        bruceFrame = 4 + (frameCounter % 4)

        if bruceX <= grassX + Self.scaledCellWidth * 0.5 {
            bruceX = grassX + Self.scaledCellWidth * 0.5
            frameCounter = 0
            state = .preTalk
        }
    }

    // State 4: Normal trot across screen (leaving)
    private func tickTrotting() {
        bruceX -= Self.trotSpeed

        if every(4) {
            frameCounter += 1
        }
        bruceFrame = 4 + (frameCounter % 4)

        if bruceX < -Self.scaledCellWidth * 2 {
            dismiss()
        }
    }

    // State 5: Triggered trot (from Call the Yak)
    private func tickTriggeredTrot() {
        if let screen = NSScreen.main {
            let screenW = screen.frame.width
            if grassX == 0 {
                grassX = screenW * 0.7
            }
            if bruceX == 0 || bruceX > screenW + Self.scaledCellWidth {
                bruceX = screenW + Self.scaledCellWidth
            }
        }

        // Quick poof-in for grass
        if grassFrame < 3 {
            if every(10) {
                frameCounter += 1
                if frameCounter <= 5 {
                    poofFrame = frameCounter - 1
                } else {
                    poofFrame = -1
                    grassFrame = 3
                }
            }
            return
        }

        bruceX -= Self.trotSpeed * 1.5
        if every(4) {
            frameCounter += 1
        }
        bruceFrame = 4 + (frameCounter % 4)

        if bruceX <= grassX + Self.scaledCellWidth * 0.5 {
            bruceX = grassX + Self.scaledCellWidth * 0.5
            frameCounter = 0
            state = .preTalk
        }
    }

    // State 6: Bubble starts growing
    private func tickPreTalk() {
        bruceFrame = 4 // Standing still

        // Grow bubble every ~0.125s (8 ticks)
        guard every(8) else { return }
        frameCounter += 1
        bubbleStage = min(frameCounter, 4)  // Cap at 4 — connectors only, no text yet

        if frameCounter >= 7 {
            frameCounter = 0
            talkingTicks = 0
            bubbleStage = 7
            selectNextQuote()
            state = .talking
        }
    }

    // Tracks how long the current quote has been displayed
    private var talkingTicks: Int = 0

    // State 7: Speech bubble with text
    private func tickTalking() {
        // Subtle grazing animation — head dips down and back
        if every(30) {
            frameCounter += 1
        }
        bruceFrame = 8 + (frameCounter % 4)

        // Display quote for a good amount of time
        // ~3-6 seconds depending on length
        talkingTicks += 1
        let displayTicks = max(180, currentQuote.count * 6)
        if talkingTicks > displayTicks {
            talkingTicks = 0
            frameCounter = 0
            state = .postTalk
        }
    }

    // State 8: Shrink bubble, then loop back to talk again
    // Original: states 7↔8 loop indefinitely — Bruce only exits via mouse proximity.
    private func tickPostTalk() {
        bruceFrame = 4

        guard every(8) else { return }
        frameCounter += 1
        bubbleStage = max(0, 7 - frameCounter)

        if frameCounter >= 7 {
            frameCounter = 0
            bubbleStage = 0
            if talkFlag {
                talkFlag = false
            }
            state = .preTalk
        }
    }

    // Scared pause counter
    private var scaredPauseTicks: Int = 0

    // State 10: Mouse-scared exit — freeze briefly, then bolt right
    private func tickRunningAway() {
        bubbleStage = 0

        // Freeze with scared face for ~0.5s before bolting
        if scaredPauseTicks < 30 {
            scaredPauseTicks += 1
            // bruceFrame stays < 17 here; scene uses that to pick scaredPause anim
            return
        }

        bruceX += Self.scaredRunSpeed
        if every(3) { frameCounter += 1 }
        bruceFrame = 17 + (frameCounter % 4)

        if let screen = NSScreen.main, bruceX > screen.frame.width + Self.scaledCellWidth * 2 {
            scaredPauseTicks = 0
            dismiss()
        }
    }

    // MARK: - Mouse Proximity

    private func checkMouseProximity() {
        // Only spook Bruce when he's grazing/talking, not while trotting or already scared
        guard isVisible,
              state == .preTalk || state == .talking || state == .postTalk
        else { return }

        let mouseLocation = NSEvent.mouseLocation
        guard let window = yakWindow else { return }

        let bruceScreenX = window.frame.origin.x + bruceX
        let bruceScreenY = window.frame.origin.y

        let dx = mouseLocation.x - bruceScreenX - Self.scaledCellWidth / 2
        let dy = mouseLocation.y - bruceScreenY - Self.scaledCellHeight / 2
        let distance = sqrt(dx * dx + dy * dy)

        if distance < Self.mouseProximity {
            state = .runningAway
            frameCounter = 0
            bubbleStage = 0
            talkingTicks = 0
            scaredPauseTicks = 0
        }
    }

    // MARK: - Quotes

    private func selectNextQuote() {
        guard !quotes.isEmpty else {
            currentQuote = "You can call me Bruce the Wonder Yak."
            return
        }
        currentQuote = quotes[quoteIndex]
        quoteIndex = (quoteIndex + 1) % quotes.count
    }
}
