// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation

final class RecordingManager: ObservableObject {
    private var disk: Disk = Disk()

    @Published var savedAnimations: [CapturedAnimation] = []

    init() {
        createDirectoriesIfNeeded()
        loadSavedAnimations()
        disk.printPaths()  // Add this to see where files are expected
    }

    private func createDirectoriesIfNeeded() {
        let fileManager = FileManager.default
        let directories = [disk.recordings, disk.animations, disk.models]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(
                        at: directory, withIntermediateDirectories: true)
                    print("Created directory at: \(directory.path)")
                } catch {
                    print(
                        "Error creating directory at \(directory.path): \(error.localizedDescription)"
                    )
                }
            } else {
                print("Directory already exists: \(directory.path)")
            }
        }
    }

    public func saveAnimation(_ animation: CapturedAnimation) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(animation)

            let safeName = animation.name.isEmpty ? "unnamed_recording" : animation.name

            let filename = "\(safeName).json"
            let fileURL = disk.animations.appendingPathComponent(filename)

            // Check if the directory exists before writing
            let directoryURL = fileURL.deletingLastPathComponent()
            let fileManager = FileManager.default

            if !fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                print("Had to create directory again: \(directoryURL.path)")
            }

            try data.write(to: fileURL)
            print("✅ Successfully saved animation to: \(fileURL.path)")

            // Verify file was created
            if fileManager.fileExists(atPath: fileURL.path) {
                let fileAttributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = fileAttributes[.size] as? UInt64 ?? 0
                print("✅ File exists with size: \(fileSize) bytes")
            } else {
                print("❌ File verification failed - file doesn't exist at path")
            }

            if !savedAnimations.contains(where: { $0.id == animation.id }) {
                savedAnimations.append(animation)
            }
        } catch {
            print("🔴 Error saving animation: \(error.localizedDescription)")
        }
    }

    public func loadSavedAnimations() {
        do {
            let fileManager = FileManager.default

            // Ensure directory exists
            if !fileManager.fileExists(atPath: disk.animations.path) {
                try fileManager.createDirectory(
                    at: disk.animations, withIntermediateDirectories: true)
                print("Created animations directory during load: \(disk.animations.path)")
                return
            }

            let fileURLs = try fileManager.contentsOfDirectory(
                at: disk.animations,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            let decoder = JSONDecoder()
            savedAnimations = []

            for url in fileURLs where url.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: url)
                    let animation = try decoder.decode(CapturedAnimation.self, from: data)
                    savedAnimations.append(animation)
                } catch {
                    print("Error decoding animation at \(url.path): \(error.localizedDescription)")
                }
            }

            print("📋 Loaded \(savedAnimations.count) animations")
        } catch {
            print("🔴 Error loading animations: \(error.localizedDescription)")
        }
    }
}
