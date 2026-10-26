import XCTest
@testable import PNG3D
import AsyncGraphics
import Spatial

final class PNG3DTests: XCTestCase {
    
    func testFile() async throws {
        let resolution = Size3D(width: 2, height: 3, depth: 4)
        var channels: [UInt8] = []
        for z in 0..<4 {
            for y in 0..<3 {
                for x in 0..<2 {
                    // Distinct values along every axis detect flipped rows,
                    // reordered slices, or swapped dimensions during the round trip.
                    channels += [UInt8(x * 255), UInt8(y * 100), UInt8(z * 70), 255]
                }
            }
        }
        let original = try await Graphic3D.channels(channels, resolution: resolution)

        let fileData = try await PNG3D.write(graphic3D: original)
        let restored = try await PNG3D.read(data: fileData)
        let restoredChannels = try await restored.channels

        XCTAssertEqual(restored.resolution, resolution)
        XCTAssertEqual(restoredChannels.count, channels.count)
        for (index, pair) in zip(restoredChannels, channels).enumerated() {
            XCTAssertEqual(pair.0, CGFloat(pair.1) / 255, accuracy: CGFloat(2) / 255,
                           "RGBA channel \(index) changed during the PNG3D round trip")
        }
    }
}
