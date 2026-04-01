import SpriteKit

/// All textures use nearest-neighbor filtering to preserve pixel art crispness.
final class SpriteSheet {
    static let cellWidth: Int = 32
    static let cellHeight: Int = 32

    private let atlas = SKTextureAtlas(named: "Bruce")

    // Pre-loaded texture arrays for SKAction.animate
    let trotTextures: [SKTexture]
    let grazeTextures: [SKTexture]
    let scaredTextures: [SKTexture]
    let grassTextures: [SKTexture]
    let poofTextures: [SKTexture]

    init() {
        grassTextures = SpriteSheet.loadSequence(atlas: atlas, prefix: "grass", count: 4)
        trotTextures = SpriteSheet.loadSequence(atlas: atlas, prefix: "trot", count: 4)
        grazeTextures = SpriteSheet.loadSequence(atlas: atlas, prefix: "graze", count: 4)
        scaredTextures = SpriteSheet.loadSequence(atlas: atlas, prefix: "scared", count: 4)
        poofTextures = SpriteSheet.loadSequence(atlas: atlas, prefix: "poof", count: 5)
    }

    private static func loadSequence(atlas: SKTextureAtlas, prefix: String, count: Int) -> [SKTexture] {
        (0..<count).map { i in
            let tex = atlas.textureNamed("\(prefix)_\(i)")
            tex.filteringMode = .nearest
            return tex
        }
    }

    // MARK: - Single texture accessors

    func grassTexture(at index: Int) -> SKTexture {
        grassTextures[index % grassTextures.count]
    }

    func trotTexture(at index: Int) -> SKTexture {
        trotTextures[index % trotTextures.count]
    }

    func grazeTexture(at index: Int) -> SKTexture {
        grazeTextures[index % grazeTextures.count]
    }

    func scaredTexture(at index: Int) -> SKTexture {
        scaredTextures[index % scaredTextures.count]
    }

    func poofTexture(at index: Int) -> SKTexture? {
        guard !poofTextures.isEmpty else { return nil }
        return poofTextures[index % poofTextures.count]
    }
}
