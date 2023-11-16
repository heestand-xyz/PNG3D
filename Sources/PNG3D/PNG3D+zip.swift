import Foundation
import Zip

extension PNG3D {
    
    static func zip(_ url: URL, as name: String) async throws -> URL {
        
        try await withCheckedThrowingContinuation { continuation in
          
            DispatchQueue.global().async {
            
                do {
                    let url = try Zip.quickZipFiles([url], fileName: name)
                    continuation.resume(returning: url)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    static func unzip(_ zipURL: URL) async throws -> URL {
        
        try await withCheckedThrowingContinuation { continuation in
           
            DispatchQueue.global().async {
            
                do {
                    let url = try Zip.quickUnzipFile(zipURL)
                    continuation.resume(returning: url)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
