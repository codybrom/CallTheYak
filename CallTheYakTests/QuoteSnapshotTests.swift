import XCTest
import SwiftUI

final class QuoteSnapshotTests: XCTestCase {

    /// Renders Bruce saying every quote and attaches the images to the test report.
    @MainActor
    func testGenerateImagesForAllQuotes() throws {
        let testBundle = Bundle(for: QuoteSnapshotTests.self)

        let url = try XCTUnwrap(testBundle.url(forResource: "Quotes", withExtension: "plist"))
        let data = try Data(contentsOf: url)
        let quotes = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String]
        )
        XCTAssertFalse(quotes.isEmpty)

        for quote in quotes {
            let renderer = ImageRenderer(content: BruceQuoteView(quote: quote, bundle: testBundle))
            renderer.scale = 2.0
            guard let image = renderer.nsImage else {
                XCTFail("Failed to render image for: \(quote)")
                continue
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = String(quote.prefix(50))
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}

// Renders Bruce grazing with a thought bubble — mirrors the in-app look.
private struct BruceQuoteView: View {
    let quote: String
    let bundle: Bundle

    // Binary-searches for the narrowest width that keeps the same line count as
    // the full 330pt max — eliminates trailing whitespace on multi-line quotes.
    private var textWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 11)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let maxWidth: CGFloat = 330

        func height(at width: CGFloat) -> CGFloat {
            ceil((quote as NSString).boundingRect(
                with: NSSize(width: width, height: 1000),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            ).size.height)
        }

        let targetHeight = height(at: maxWidth)
        var lo: CGFloat = 1
        var hi: CGFloat = maxWidth
        while hi - lo > 0.5 {
            let mid = (lo + hi) / 2
            if height(at: mid) <= targetHeight { hi = mid } else { lo = mid }
        }
        return ceil(hi)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(quote)
                .font(.system(size: 11))
                .multilineTextAlignment(.leading)
                .frame(width: textWidth, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black, lineWidth: 1))
                )

            // Connector dots between bubble and Bruce
            HStack(spacing: 3) {
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(.black, lineWidth: 1))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(.black, lineWidth: 1))
                    .frame(width: 6, height: 6)
            }

            // Bruce standing on grass
            ZStack(alignment: .bottom) {
                Image("grass_3", bundle: bundle)
                    .interpolation(.none)
                    .frame(width: 32, height: 32)
                Image("graze_0", bundle: bundle)
                    .interpolation(.none)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(8)
        .fixedSize()
    }
}
