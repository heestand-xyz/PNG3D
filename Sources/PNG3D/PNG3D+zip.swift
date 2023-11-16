import Foundation

extension PNG3D {
    
    static func zip(_ url: URL, as name: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            var error: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [.forUploading], error: &error) { zipURL in
                do {
                    let data = try Data(contentsOf: zipURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let error: NSError {
                continuation.resume(throwing: error)
            }
        }
    }
}
