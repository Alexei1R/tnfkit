//
//  Disk.swift
//  Motionlink
//
//  Created by rusu alexei on 11.03.2025.
//

import Foundation

struct Disk {
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
