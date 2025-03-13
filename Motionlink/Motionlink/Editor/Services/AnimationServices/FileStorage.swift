// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation

struct FileStorage {
    let localRoot = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first!

    var recordings: URL {
        localRoot.appendingPathComponent("Recordings", conformingTo: .folder)
    }
    var models: URL {
        localRoot.appendingPathComponent("Models", conformingTo: .folder)
    }

    var animations: URL {
        localRoot.appendingPathComponent("Animations", conformingTo: .folder)
    }

    // For debugging, print the full path to help locate files
    func printPaths() {
        print("📁 Document Root: \(localRoot.path)")
        print("📁 Animations Directory: \(animations.path)")
        print("📁 Recordings Directory: \(recordings.path)")
        print("📁 Models Directory: \(models.path)")
    }
}
