import Foundation
import CryptoKit
import UIKit

// Team crests for the live-match card. A widget cannot fetch images while it
// renders, so the app downloads each crest once into the shared App Group
// container and the widget reads it from disk. Files are named by a hash of
// the URL, so a new crest URL is a new file and an old one is never shown.
enum CrestStore {
    static let group = "group.il.co.hapoelhadera.app"

    static var directory: URL? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        let dir = base.appendingPathComponent("crests", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func file(for url: String) -> URL? {
        guard !url.isEmpty, let dir = directory else { return nil }
        let hash = SHA256.hash(data: Data(url.utf8)).map { String(format: "%02x", $0) }.joined().prefix(24)
        return dir.appendingPathComponent(String(hash))
    }

    static func image(for url: String) -> UIImage? {
        guard let f = file(for: url), let data = try? Data(contentsOf: f) else { return nil }
        return UIImage(data: data)
    }

    static func has(_ url: String) -> Bool {
        guard let f = file(for: url) else { return false }
        return FileManager.default.fileExists(atPath: f.path)
    }

    // Download if not cached. Completion runs once per call, on any thread,
    // with `true` when the crest is on disk afterwards.
    static func fetch(_ url: String, completion: @escaping (Bool) -> Void) {
        guard let f = file(for: url), let u = URL(string: url) else { completion(false); return }
        if FileManager.default.fileExists(atPath: f.path) { completion(true); return }
        URLSession.shared.dataTask(with: u) { data, resp, _ in
            guard let data, (resp as? HTTPURLResponse)?.statusCode == 200, UIImage(data: data) != nil else { completion(false); return }
            do { try data.write(to: f, options: .atomic); completion(true) } catch { completion(false) }
        }.resume()
    }
}
