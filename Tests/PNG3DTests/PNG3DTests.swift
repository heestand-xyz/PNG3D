import XCTest
@testable import PNG3D
import AsyncGraphics
import Spatial

final class PNG3DTests: XCTestCase {
    
    func testFile() async throws {
        
        let resolution = Size3D(width: 100, height: 100, depth: 100)
        let graphic3D: Graphic3D = try await .sphere(color: .green, resolution: resolution)
        let fileData: Data = try await PNG3D.write(graphic3D: graphic3D)
        
//        if #available(macOS 13.0, *) {
//            let url = URL(filePath: "/Users/.../Desktop/test.png3d")
//            try fileData.write(to: url)
//        }
        
        let _: Graphic3D = try await PNG3D.read(data: fileData)
    }
}
