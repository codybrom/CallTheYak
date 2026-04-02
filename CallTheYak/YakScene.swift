import SpriteKit

/// SpriteKit scene that renders Bruce the Wonder Yak.
/// Pure renderer — reads state from YakManager each frame.
final class YakScene: SKScene {
    private weak var manager: YakManager?

    // Sprite nodes
    private let bruceNode = SKSpriteNode()
    private let grassNode = SKSpriteNode()
    private let poofNode = SKSpriteNode()

    // Thought bubble nodes
    private let bubbleGroup = SKNode()
    private let smallCircle = SKShapeNode(circleOfRadius: 3)
    private let bigCircle = SKShapeNode(circleOfRadius: 5)
    private var bubbleShape = SKShapeNode()
    private let bubbleLabel = SKLabelNode()

    // Pre-built animation actions
    private var trotAction: SKAction?
    private var grazeAction: SKAction?
    private var scaredAction: SKAction?

    // Track current animation to avoid re-applying
    private var currentAnimKey: String = ""

    // Track current quote to rebuild bubble only when it changes
    private var renderedQuote: String = ""

    private let scale: CGFloat = YakManager.renderScale
    private let baseY: CGFloat = 4

    init(manager: YakManager, size: CGSize) {
        self.manager = manager
        super.init(size: size)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0, y: 0)
        backgroundColor = .clear
        scaleMode = .resizeFill

        setupNodes()
        buildActions()
    }

    private func setupNodes() {
        // All sprite nodes use bottom-left anchor to match existing coordinate system
        let bottomLeft = CGPoint(x: 0, y: 0)

        let cellSize = CGSize(width: SpriteSheet.cellWidth, height: SpriteSheet.cellHeight)

        bruceNode.anchorPoint = bottomLeft
        bruceNode.size = cellSize
        bruceNode.setScale(scale)
        bruceNode.isHidden = true
        bruceNode.zPosition = 10
        addChild(bruceNode)

        grassNode.anchorPoint = bottomLeft
        grassNode.size = cellSize
        grassNode.setScale(scale)
        grassNode.isHidden = true
        grassNode.zPosition = 5
        addChild(grassNode)

        poofNode.anchorPoint = bottomLeft
        poofNode.size = CGSize(width: 42, height: 42)
        poofNode.setScale(scale)
        poofNode.isHidden = true
        poofNode.zPosition = 15
        addChild(poofNode)

        // Thought bubble group
        bubbleGroup.zPosition = 20
        bubbleGroup.isHidden = true
        addChild(bubbleGroup)

        // Connector circles — white fill, black 1px stroke
        configureCircle(smallCircle, radius: 3)
        configureCircle(bigCircle, radius: 5)
        bubbleGroup.addChild(smallCircle)
        bubbleGroup.addChild(bigCircle)

        // Bubble shape (placeholder, rebuilt when quote changes)
        bubbleShape.fillColor = .white
        bubbleShape.strokeColor = .black
        bubbleShape.lineWidth = 1
        bubbleShape.zPosition = 0
        bubbleGroup.addChild(bubbleShape)

        // Label
        bubbleLabel.fontName = NSFont.systemFont(ofSize: 11).fontName
        bubbleLabel.fontSize = 11
        bubbleLabel.fontColor = .black
        bubbleLabel.numberOfLines = 0
        bubbleLabel.preferredMaxLayoutWidth = 330
        bubbleLabel.horizontalAlignmentMode = .left
        bubbleLabel.verticalAlignmentMode = .center
        bubbleLabel.zPosition = 1
        bubbleGroup.addChild(bubbleLabel)
    }

    private func configureCircle(_ node: SKShapeNode, radius: CGFloat) {
        node.fillColor = .white
        node.strokeColor = .black
        node.lineWidth = 1
    }

    private func buildActions() {
        guard let sheet = manager?.spriteSheet else { return }

        let trotFrameTime: TimeInterval = 4.0 / 60.0   // Every 4 ticks at 60fps
        let grazeFrameTime: TimeInterval = 30.0 / 60.0  // Every 30 ticks
        let scaredFrameTime: TimeInterval = 3.0 / 60.0  // Every 3 ticks

        trotAction = SKAction.repeatForever(
            SKAction.animate(with: sheet.trotTextures, timePerFrame: trotFrameTime, resize: true, restore: false)
        )
        grazeAction = SKAction.repeatForever(
            SKAction.animate(with: sheet.grazeTextures, timePerFrame: grazeFrameTime, resize: true, restore: false)
        )
        scaredAction = SKAction.repeatForever(
            SKAction.animate(with: sheet.scaredTextures, timePerFrame: scaredFrameTime, resize: true, restore: false)
        )
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard let manager else { return }
        guard manager.isVisible else { return }

        manager.tick()
        syncNodes(manager)
    }

    private func syncNodes(_ manager: YakManager) {
        // --- Bruce ---
        if manager.bruceFrame >= 0 {
            bruceNode.isHidden = false
            bruceNode.position = CGPoint(x: manager.bruceX, y: baseY)

            // Determine which animation should be running
            let desiredAnim: String
            if manager.state == .runningAway && manager.bruceFrame < 17 {
                // Scared freeze — bruceFrame hasn't been set to running range yet
                desiredAnim = "scaredPause"
            } else if manager.state == .runningAway {
                desiredAnim = "scared"
            } else if manager.state == .talking {
                desiredAnim = "graze"
            } else if manager.state == .preTalk || manager.state == .postTalk {
                desiredAnim = "stand"
            } else {
                // entering, trotting, triggeredTrot, preExit (while bruce visible)
                desiredAnim = "trot"
            }
            bruceNode.xScale = scale

            if desiredAnim != currentAnimKey {
                currentAnimKey = desiredAnim
                bruceNode.removeAction(forKey: "anim")

                switch desiredAnim {
                case "trot":
                    if let action = trotAction { bruceNode.run(action, withKey: "anim") }
                case "graze":
                    if let action = grazeAction { bruceNode.run(action, withKey: "anim") }
                case "scared":
                    if let action = scaredAction { bruceNode.run(action, withKey: "anim") }
                case "stand":
                    if let tex = manager.spriteSheet?.trotTexture(at: 1) {
                        bruceNode.texture = tex
                    }
                case "scaredPause":
                    if let tex = manager.spriteSheet?.scaredTexture(at: 0) {
                        bruceNode.texture = tex
                    }
                default:
                    break
                }
            }

        } else {
            bruceNode.isHidden = true
            currentAnimKey = ""
        }

        // --- Grass ---
        if manager.grassFrame >= 0, manager.poofFrame < 0,
           let tex = manager.spriteSheet?.grassTexture(at: manager.grassFrame) {
            grassNode.isHidden = false
            grassNode.texture = tex
            grassNode.size = tex.size()
            grassNode.position = CGPoint(x: manager.grassX, y: baseY)
        } else {
            grassNode.isHidden = true
        }

        // --- Poof ---
        if manager.poofFrame >= 0,
           let tex = manager.spriteSheet?.poofTexture(at: manager.poofFrame) {
            poofNode.isHidden = false
            poofNode.texture = tex
            poofNode.size = tex.size()
            let cellW = YakManager.scaledCellWidth
            let poofW: CGFloat = 42 * scale
            poofNode.position = CGPoint(
                x: manager.grassX + (cellW - poofW) / 2,
                y: baseY
            )
        } else {
            poofNode.isHidden = true
        }

        // --- Thought Bubble ---
        syncBubble(manager)
    }

    // MARK: - Thought Bubble

    private func syncBubble(_ manager: YakManager) {
        let stage = manager.bubbleStage

        guard stage > 0, manager.bruceFrame >= 0 else {
            bubbleGroup.isHidden = true
            renderedQuote = ""
            return
        }

        bubbleGroup.isHidden = false

        let cellH = YakManager.scaledCellHeight
        let bruceLeft = manager.bruceX
        let connectorY = baseY + cellH * 0.6

        // Small circle — visible from stage 1
        smallCircle.isHidden = stage < 1
        smallCircle.position = CGPoint(x: bruceLeft - 6, y: connectorY)

        // Big circle — visible from stage 3
        bigCircle.isHidden = stage < 3
        bigCircle.position = CGPoint(x: bruceLeft - 20, y: connectorY + 4)

        // Bubble with text — visible from stage 5
        let showBubble = stage >= 5 && !manager.currentQuote.isEmpty
        bubbleShape.isHidden = !showBubble
        bubbleLabel.isHidden = !showBubble

        if showBubble {
            // Only rebuild when quote changes
            if manager.currentQuote != renderedQuote {
                renderedQuote = manager.currentQuote
                rebuildBubble(quote: manager.currentQuote, anchorX: bruceLeft - 24, anchorY: connectorY + 4)
            }
        }
    }

    private func rebuildBubble(quote: String, anchorX: CGFloat, anchorY: CGFloat) {
        let padding: CGFloat = 6
        let cornerRadius: CGFloat = 10
        let maxTextWidth: CGFloat = 330

        // Measure text
        let font = NSFont.systemFont(ofSize: 11)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (quote as NSString).boundingRect(
            with: NSSize(width: maxTextWidth, height: 200),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        ).size

        let bubbleW = ceil(textSize.width) + padding * 2
        let bubbleH = max(ceil(textSize.height) + padding * 2, 20)

        // Position bubble to the left of the anchor point
        let bubbleX = anchorX - bubbleW - 4
        let bubbleY = anchorY - bubbleH / 2

        // Rebuild shape
        let rect = CGRect(x: bubbleX, y: bubbleY, width: bubbleW, height: bubbleH)
        bubbleShape.removeFromParent()
        bubbleShape = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
        bubbleShape.fillColor = .white
        bubbleShape.strokeColor = .black
        bubbleShape.lineWidth = 1
        bubbleShape.zPosition = 0
        bubbleGroup.addChild(bubbleShape)

        // Position label
        bubbleLabel.text = quote
        bubbleLabel.preferredMaxLayoutWidth = maxTextWidth
        bubbleLabel.position = CGPoint(
            x: bubbleX + padding,
            y: bubbleY + bubbleH / 2
        )
    }
}
