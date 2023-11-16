import XCTest
@testable import PNG3D
import AsyncGraphics

final class PNG3DTests: XCTestCase {
    
    func testFile() async throws {
        
        let resolution = SIMD3<Int>(100, 100, 100)
        let graphic3D: Graphic3D = try await .sphere(resolution: resolution)
        let fileData = try await PNG3D.write(graphic3D)
        
//        if #available(macOS 13.0, *) {
//            let url = URL(filePath: "/Users/.../Desktop/test.png3d")
//            try fileData.write(to: url)
//        }
    }
}
