import SpriteKit

/// Minimal SKView subclass that passes all clicks through.
final class YakSKView: SKView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
