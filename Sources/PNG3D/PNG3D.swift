import Foundation
import AsyncGraphics
import TextureMap

public struct PNG3D {
    
    private static let fileName: String = "PNG3D"
    
    static func write(_ graphic3D: Graphic3D) async throws -> Data {
        
        /// Graphics
        
        let graphics: [Graphic] = try await graphic3D.samples()
        
        /// Images
        
        let images: [Data] = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            
            for (index, layer) in graphics.enumerated() {
                group.addTask {
                    let image: Data = try await layer.pngData
                    return (index, image)
                }
            }
            
            var images: [Int: Data] = [:]
            for try await (index, image) in group {
                images[index] = image
            }
            
            return Array(images)
                .sorted(by: { $0.key < $1.key })
                .map(\.value)
        }
        
        /// File
        
        let tempURL = FileManager.default.temporaryDirectory
        
        let fileURL = tempURL
            .appendingPathComponent(Self.fileName)
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: false)
        
        /// Info
        
        let resolution = PNG3DResolution(width: graphic3D.width,
                                         height: graphic3D.height,
                                         depth: graphic3D.depth)
        let info = PNG3DInfo(resolution: resolution)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let infoData = try encoder.encode(info)
        
        let infoFileURL = fileURL.appendingPathComponent("info", conformingTo: .json)
        try infoData.write(to: infoFileURL)
        
        /// Layers
        
        let layersFolderURL = fileURL
            .appendingPathComponent("layers")
        try FileManager.default.createDirectory(at: layersFolderURL, withIntermediateDirectories: false)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            
            for (index, image) in images.enumerated() {
                let layerFileURL = layersFolderURL.appendingPathComponent("layer_\(index)", conformingTo: .png)
                group.addTask {
                    try image.write(to: layerFileURL)
                }
            }
            
            try await group.waitForAll()
        }
        
        let zipData: Data = try await zip(fileURL, as: Self.fileName)
        
        try FileManager.default.removeItem(at: fileURL)
        
        return zipData
    }
}
