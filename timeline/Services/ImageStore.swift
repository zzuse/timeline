import Foundation
import UIKit

final class ImageStore {
    enum ImageStoreError: Error {
        case invalidData
        case missingFile
    }

    private let fileManager = FileManager.default
    private let folderName = "Images"

    private var baseURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName)
    }

    init() {
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func save(images: [UIImage]) throws -> [String] {
        var paths: [String] = []
        for image in images {
            guard let data = image.jpegData(compressionQuality: 0.82) else {
                throw ImageStoreError.invalidData
            }
            let filename = UUID().uuidString + ".jpg"
            let url = baseURL.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            paths.append(filename)
        }
        return paths
    }

    func load(path: String) throws -> UIImage {
        let url = baseURL.appendingPathComponent(path)
        guard fileManager.fileExists(atPath: url.path) else {
            throw ImageStoreError.missingFile
        }
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw ImageStoreError.invalidData
        }
        return image
    }

    func delete(paths: [String]) throws {
        for path in paths {
            let url = baseURL.appendingPathComponent(path)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }
}

final class AudioStore {
    enum AudioStoreError: Error {
        case missingFile
    }

    private let fileManager = FileManager.default
    private let folderName = "Audio"

    private var baseURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName)
    }

    init() {
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func makeRecordingURL() -> (url: URL, filename: String) {
        let filename = UUID().uuidString + ".m4a"
        let url = baseURL.appendingPathComponent(filename)
        return (url, filename)
    }

    func url(for path: String) throws -> URL {
        let url = baseURL.appendingPathComponent(path)
        guard fileManager.fileExists(atPath: url.path) else {
            throw AudioStoreError.missingFile
        }
        return url
    }

    func delete(paths: [String]) throws {
        for path in paths {
            let url = baseURL.appendingPathComponent(path)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }
}
