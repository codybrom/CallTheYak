import AppKit
import SpriteKit

/// Transparent borderless window that spans the bottom of the screen.
/// Named after "trojanYakDesktopWindow" from the original FCP4 binary.
final class YakWindow: NSPanel {
    let skView: YakSKView
    let scene: YakScene

    static let windowHeight: CGFloat = 300

    init(manager: YakManager) {
        self.skView = YakSKView()
        self.scene = YakScene(manager: manager, size: .zero)

        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.ignoresMouseEvents = false
        self.isMovable = false
        self.hidesOnDeactivate = false

        // Critical for transparent SpriteKit rendering
        skView.allowsTransparency = true

        self.contentView = skView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func showOnScreen() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        let windowFrame = NSRect(
            x: visibleFrame.origin.x,
            y: visibleFrame.origin.y,
            width: visibleFrame.width,
            height: Self.windowHeight
        )
        setFrame(windowFrame, display: true)

        // Present scene if not already
        if skView.scene == nil {
            scene.size = CGSize(width: windowFrame.width, height: windowFrame.height)
            skView.presentScene(scene)
        } else {
            scene.size = CGSize(width: windowFrame.width, height: windowFrame.height)
        }

        orderFrontRegardless()
    }
}
