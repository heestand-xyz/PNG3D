import Foundation
import AsyncGraphics
import TextureMap

public struct PNG3D {
    
    public static let fileExtension: String = "png3d"
    
    private static let folderName: String = fileExtension
    private static let fileName: String = "image"
    private static let infoName: String = "info"
    private static let layersName: String = "layers"
    private static let layerName: String = "layer"
    
    public enum PNG3DError: LocalizedError {
        case noFolderFound
        case noInfoFileFound
        case noLayersFolderFound
        case noLayerFileFound(index: Int)
        public var errorDescription: String? {
            switch self {
            case .noFolderFound:
                return "PNG3D - No Folder Found"
            case .noInfoFileFound:
                return "PNG3D - No Info File Found"
            case .noLayersFolderFound:
                return "PNG3D - No Layers Folder Found"
            case .noLayerFileFound(let index):
                return "PNG3D - No Layer File Found at Index \(index)"
            }
        }
    }
    
    public static func read(data: Data) async throws -> Graphic3D {
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("png3d_read_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: false)
        
        let url = tempURL.appendingPathComponent("temp.\(Self.fileExtension)")
        
        try data.write(to: url)
        
        let graphic3D: Graphic3D = try await read(url: url)
        
        try FileManager.default.removeItem(at: tempURL)
        
        return graphic3D
    }
    
    public static func read(url: URL) async throws -> Graphic3D {
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("png3d_read_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: false)

        let zipURL: URL = tempURL
            .appendingPathComponent("temp.zip")
        try FileManager.default.copyItem(at: url, to: zipURL)
        
        let folderURL: URL = try await unzip(zipURL)
            .appendingPathComponent(Self.folderName)
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            throw PNG3DError.noFolderFound
        }
        
        /// Info
        
        let infoFileURL = folderURL.appendingPathComponent(Self.infoName, conformingTo: .json)
        guard FileManager.default.fileExists(atPath: infoFileURL.path) else {
            throw PNG3DError.noInfoFileFound
        }
        
        let decoder = JSONDecoder()
        
        let infoData: Data = try Data(contentsOf: infoFileURL)
        let info: PNG3DInfo = try decoder.decode(PNG3DInfo.self, from: infoData)
        let resolution: PNG3DResolution = info.resolution
        
        /// Layers
        
        let layersFolderURL = folderURL
            .appendingPathComponent(Self.layersName)
        guard FileManager.default.fileExists(atPath: layersFolderURL.path) else {
            throw PNG3DError.noLayersFolderFound
        }
        
        /// Graphics
        
        var graphics: [Graphic] = []
        for index in 0..<resolution.depth {
            let layerFileURL = layersFolderURL.appendingPathComponent("\(Self.layerName)_\(index)", conformingTo: .png)
            guard FileManager.default.fileExists(atPath: layerFileURL.path) else {
                throw PNG3DError.noLayerFileFound(index: index)
            }
            let graphic: Graphic = try await .image(url: layerFileURL)
            graphics.append(graphic)
        }
        
        /// Graphic 3D
        
        let graphic3D: Graphic3D = try await .construct(graphics: graphics)
        
        try FileManager.default.removeItem(at: tempURL)

        return graphic3D
    }
    
    public static func write(graphic3D: Graphic3D) async throws -> Data {
        let url: URL = try await write(graphic3D: graphic3D)
        let data = try Data(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        return data
    }
    
    public static func write(graphic3D: Graphic3D) async throws -> URL {
        
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
            .appendingPathComponent("png3d_write_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: false)
        
        let folderURL = tempURL
            .appendingPathComponent(Self.folderName)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        
        /// Info
        
        let resolution = PNG3DResolution(width: graphic3D.width,
                                         height: graphic3D.height,
                                         depth: graphic3D.depth)
        let info = PNG3DInfo(resolution: resolution)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let infoData = try encoder.encode(info)
        
        let infoFileURL = folderURL.appendingPathComponent(Self.infoName, conformingTo: .json)
        try infoData.write(to: infoFileURL)
        
        /// Layers
        
        let layersFolderURL = folderURL
            .appendingPathComponent(Self.layersName)
        try FileManager.default.createDirectory(at: layersFolderURL, withIntermediateDirectories: false)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            
            for (index, image) in images.enumerated() {
                let layerFileURL = layersFolderURL.appendingPathComponent("\(Self.layerName)_\(index)", conformingTo: .png)
                group.addTask {
                    try image.write(to: layerFileURL)
                }
            }
            
            try await group.waitForAll()
        }
        
        let zipURL: URL = try await zip(folderURL, as: Self.fileName)

        try FileManager.default.removeItem(at: tempURL)

        let png3dURL: URL = zipURL
            .deletingPathExtension()
            .appendingPathExtension(Self.fileExtension)
        try FileManager.default.moveItem(at: zipURL, to: png3dURL)
        
        return png3dURL
    }
}
