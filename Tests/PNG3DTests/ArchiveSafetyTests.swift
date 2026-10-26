import Foundation
import XCTest
@testable import PNG3D

final class ArchiveSafetyTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PNG3DTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testUnsafeEntriesAreRejectedBeforeAnyExtraction() async throws {
        let destination = directory.appendingPathComponent("contents", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let escaped = directory.appendingPathComponent("escaped.txt")
        try Data("original".utf8).write(to: escaped)

        let unsafeNames = [
            "../escaped.txt", "nested/../../escaped.txt", "/escaped.txt",
            "..\\escaped.txt", "C:/escaped.txt", "./escaped.txt",
            "nested//escaped.txt", "safe\0/../escaped.txt"
        ]
        for name in unsafeNames {
            let archive = try makeArchive([
                Entry("safe.txt", "safe"), Entry(name, "overwritten")
            ])
            do {
                try await PNG3D.unzip(archive, to: destination)
                XCTFail("Accepted unsafe entry: \(name)")
            } catch PNG3D.PNG3DError.unsafeArchivePath {
                // All entries must be checked before safe.txt is written too.
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("safe.txt").path))
            XCTAssertEqual(try String(contentsOf: escaped, encoding: .utf8), "original")
        }
    }

    func testSymbolicLinksAreRejected() async throws {
        let archive = try makeArchive([Entry("link", "../", attributes: 0o120777 << 16)])
        do {
            _ = try await PNG3D.withUnzippedArchive(at: archive) { $0 }
            XCTFail("Accepted a symbolic link")
        } catch PNG3D.PNG3DError.unsafeArchivePath {}
    }

    func testConcurrentReadsUseIndependentDirectories() async throws {
        let archives = try ["first", "second"].map {
            try makeArchive([Entry("png3d/info.json", $0)])
        }
        let barrier = ImportBarrier()
        let results = try await withThrowingTaskGroup(of: (URL, String).self) { group in
            for archive in archives {
                group.addTask {
                    try await PNG3D.withUnzippedArchive(at: archive) { contents in
                        try await barrier.waitForBoth()
                        let value = try String(contentsOf: contents.appendingPathComponent("png3d/info.json"), encoding: .utf8)
                        return (contents, value)
                    }
                }
            }
            var results: [(URL, String)] = []
            for try await result in group { results.append(result) }
            return results
        }
        XCTAssertEqual(Set(results.map(\.1)), ["first", "second"])
        XCTAssertEqual(Set(results.map(\.0)).count, 2)
        for (contents, _) in results {
            XCTAssertFalse(FileManager.default.fileExists(atPath: contents.deletingLastPathComponent().path))
        }
    }

    func testMissingFilesCannotReuseEarlierArchiveContents() async throws {
        let first = try makeArchive([Entry("png3d/info.json", "old")])
        _ = try await PNG3D.withUnzippedArchive(at: first) { contents in
            XCTAssertTrue(FileManager.default.fileExists(atPath: contents.appendingPathComponent("png3d/info.json").path))
        }
        let second = try makeArchive([Entry("png3d/layers/layer_0.png", "new")])
        do {
            _ = try await PNG3D.read(url: second)
            XCTFail("Reused info.json from an earlier import")
        } catch PNG3D.PNG3DError.noInfoFileFound {}
    }

    func testTemporaryFilesAreRemovedWhenReadingThrows() async throws {
        let archive = try makeArchive([Entry("png3d/info.json", "content")])
        var extracted: URL?
        do {
            try await PNG3D.withUnzippedArchive(at: archive) { contents in
                extracted = contents
                throw TestError.expected
            }
            XCTFail("Expected operation to throw")
        } catch TestError.expected {}
        let contents = try XCTUnwrap(extracted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: contents.deletingLastPathComponent().path))
    }

    func testNonPositiveDimensionsThrowBeforeLoadingImages() async throws {
        for dimension in [0, -1] {
            let metadata = "{\"resolution\":{\"width\":1,\"height\":1,\"depth\":\(dimension)}}"
            let archive = try makeArchive([Entry("png3d/info.json", metadata)])
            do {
                _ = try await PNG3D.read(url: archive)
                XCTFail("Accepted depth \(dimension)")
            } catch PNG3D.PNG3DError.invalidResolution {}
        }
    }

    private enum TestError: Error { case expected }

    private actor ImportBarrier {
        private var first: CheckedContinuation<Void, Error>?
        func waitForBoth() async throws {
            try Task.checkCancellation()
            if let first {
                self.first = nil
                first.resume()
            } else {
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { first = $0 }
                } onCancel: {
                    Task { await self.cancel() }
                }
            }
        }

        private func cancel() {
            first?.resume(throwing: CancellationError())
            first = nil
        }
    }

    private struct Entry {
        let name: Data
        let contents: Data
        let attributes: UInt32
        init(_ name: String, _ contents: String, attributes: UInt32 = 0) {
            self.name = Data(name.utf8)
            self.contents = Data(contents.utf8)
            self.attributes = attributes
        }
    }

    /// Stored ZIP entries make hostile names testable without an archiver
    /// normalizing or rejecting them before the importer sees them.
    private func makeArchive(_ entries: [Entry]) throws -> URL {
        var archive = Data()
        var centralDirectory = Data()
        for entry in entries {
            let offset = UInt32(archive.count)
            let checksum = crc32(entry.contents)
            archive.appendLE(UInt32(0x04034b50))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(0x800)) // UTF-8 names
            archive.appendLE(UInt16(0)) // Stored, not compressed
            archive.appendLE(UInt32(0)) // Time and date
            archive.appendLE(checksum)
            archive.appendLE(UInt32(entry.contents.count))
            archive.appendLE(UInt32(entry.contents.count))
            archive.appendLE(UInt16(entry.name.count))
            archive.appendLE(UInt16(0))
            archive.append(entry.name)
            archive.append(entry.contents)

            centralDirectory.appendLE(UInt32(0x02014b50))
            centralDirectory.appendLE(UInt16(0x0314)) // Unix creator
            centralDirectory.appendLE(UInt16(20))
            centralDirectory.appendLE(UInt16(0x800))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt32(0))
            centralDirectory.appendLE(checksum)
            centralDirectory.appendLE(UInt32(entry.contents.count))
            centralDirectory.appendLE(UInt32(entry.contents.count))
            centralDirectory.appendLE(UInt16(entry.name.count))
            centralDirectory.appendLE(UInt16(0)) // Extra
            centralDirectory.appendLE(UInt16(0)) // Comment
            centralDirectory.appendLE(UInt16(0)) // Disk
            centralDirectory.appendLE(UInt16(0)) // Internal attributes
            centralDirectory.appendLE(entry.attributes)
            centralDirectory.appendLE(offset)
            centralDirectory.append(entry.name)
        }
        let directoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendLE(UInt32(0x06054b50))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(entries.count))
        archive.appendLE(UInt16(entries.count))
        archive.appendLE(UInt32(centralDirectory.count))
        archive.appendLE(directoryOffset)
        archive.appendLE(UInt16(0))
        let url = directory.appendingPathComponent("\(UUID().uuidString).zip")
        try archive.write(to: url)
        return url
    }

    private func crc32(_ bytes: Data) -> UInt32 {
        var checksum = UInt32.max
        for byte in bytes {
            checksum ^= UInt32(byte)
            for _ in 0..<8 {
                checksum = (checksum >> 1) ^ (checksum & 1 == 0 ? 0 : 0xedb88320)
            }
        }
        return ~checksum
    }
}

private extension Data {
    mutating func appendLE<Value: FixedWidthInteger>(_ value: Value) {
        var value = value.littleEndian
        Swift.withUnsafeBytes(of: &value) { append(contentsOf: $0) }
    }
}
