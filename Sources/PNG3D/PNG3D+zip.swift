import Foundation
import Zip
@_implementationOnly import Minizip

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
    
    /// Keep both the archive snapshot and its extracted files private to this read.
    /// QuickZip extracts by basename in Documents, so it must not be used here.
    static func withUnzippedArchive<Result>(
        at archiveURL: URL,
        _ operation: (URL) async throws -> Result
    ) async throws -> Result {
        let fileManager = FileManager.default
        let temporaryURL = fileManager.temporaryDirectory
            .appendingPathComponent("png3d_read_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryURL, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: temporaryURL) }

        let zipURL = temporaryURL.appendingPathComponent("archive.zip")
        try fileManager.copyItem(at: archiveURL, to: zipURL)
        let destination = temporaryURL.appendingPathComponent("contents", isDirectory: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: false)
        try await unzip(zipURL, to: destination)
        return try await operation(destination)
    }

    static func unzip(_ zipURL: URL, to destination: URL) async throws {
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
           
            DispatchQueue.global().async {
            
                do {
                    // Inspect every entry with the same parser that Zip uses, before
                    // allowing it to write even the first file.
                    try validateArchive(at: zipURL)
                    try Zip.unzipFile(zipURL, destination: destination, overwrite: false, password: nil)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func validateArchive(at url: URL) throws {
        guard let archive = unzOpen64(url.path) else {
            throw PNG3DError.invalidArchive
        }
        defer { unzClose(archive) }

        var status = unzGoToFirstFile(archive)
        guard status == UNZ_OK else { throw PNG3DError.invalidArchive }
        var paths: Set<String> = []

        while status == UNZ_OK {
            var info = unz_file_info64()
            guard unzGetCurrentFileInfo64(archive, &info, nil, 0, nil, 0, nil, 0) == UNZ_OK,
                  info.size_filename > 0,
                  info.size_filename <= UInt16.max else {
                throw PNG3DError.invalidArchive
            }
            var filename = [CChar](repeating: 0, count: Int(info.size_filename) + 1)
            guard unzGetCurrentFileInfo64(archive, &info, &filename, UInt(filename.count), nil, 0, nil, 0) == UNZ_OK else {
                throw PNG3DError.invalidArchive
            }
            let bytes = filename.dropLast().map { UInt8(bitPattern: $0) }
            guard !bytes.contains(0), let path = String(bytes: bytes, encoding: .utf8) else {
                throw PNG3DError.unsafeArchivePath
            }

            // Reject alternate separators and ambiguous components instead of
            // normalizing them differently from the extraction library.
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            let pathComponents = path.hasSuffix("/") ? components.dropLast() : components[...]
            guard !path.contains("\\"), !path.contains(":"),
                  !pathComponents.isEmpty,
                  pathComponents.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
                  paths.insert(pathComponents.joined(separator: "/")).inserted else {
                throw PNG3DError.unsafeArchivePath
            }

            // A fresh extraction directory contains no links. Reject archived links
            // and special files as well, even if an extractor later supports them.
            let fileType = (info.external_fa >> 16) & 0o170000
            guard fileType == 0 || fileType == 0o100000 || fileType == 0o040000 else {
                throw PNG3DError.unsafeArchivePath
            }
            status = unzGoToNextFile(archive)
        }
        guard status == UNZ_END_OF_LIST_OF_FILE else { throw PNG3DError.invalidArchive }
    }
}
