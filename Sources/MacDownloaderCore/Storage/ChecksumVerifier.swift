import Foundation
import CryptoKit

/// Cryptographic hash calculator and integrity verifier for downloaded files.
public struct ChecksumVerifier: Sendable {

    public enum HashAlgorithm: String, Sendable, CaseIterable {
        case sha256 = "SHA-256"
        case md5 = "MD5"
    }

    /// Computes the SHA-256 checksum for a file on disk using streaming chunks.
    public static func computeSHA256(for fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        let bufferSize = 64 * 1024

        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: bufferSize)
            guard !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Computes the MD5 checksum for a file on disk using streaming chunks.
    public static func computeMD5(for fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = Insecure.MD5()
        let bufferSize = 64 * 1024

        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: bufferSize)
            guard !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Verifies if the file at URL matches the expected hash.
    public static func verify(fileURL: URL, expectedHash: String, algorithm: HashAlgorithm = .sha256) throws -> Bool {
        let calculated: String
        switch algorithm {
        case .sha256:
            calculated = try computeSHA256(for: fileURL)
        case .md5:
            calculated = try computeMD5(for: fileURL)
        }

        return calculated.caseInsensitiveCompare(expectedHash.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }
}
