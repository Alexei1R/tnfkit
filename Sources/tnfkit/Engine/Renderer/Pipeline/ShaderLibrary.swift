// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import MetalKit

public final class ShaderLibrary: @unchecked Sendable {
    public static let shared = ShaderLibrary()

    public let shaderLibrary: MTLLibrary

    private init() {
        // NOTE: Create a singleton library
        guard let device = Device.shared?.device else {
            fatalError("Failed to create Metal device")
        }

        var library: MTLLibrary

        if let bundleURL = Bundle.main.url(
            forResource: "tnfkit_tnfkit", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL)
        {
            do {
                let bundleLibrary = try device.makeDefaultLibrary(bundle: bundle)
                library = bundleLibrary
                Log.info("Shader library loaded from bundle successfully")
            } catch let error as NSError {
                Log.error(
                    "Failed to load shader library from bundle: \(error.localizedDescription)")
                if let compileErrors = error.userInfo["MTLCompilerErrors"] as? [String] {
                    for err in compileErrors {
                        Log.error("Shader compile error: \(err)")
                    }
                }

                guard let defaultLibrary = device.makeDefaultLibrary() else {
                    fatalError("Failed to create default shader library")
                }
                library = defaultLibrary
                Log.info("Falling back to default shader library")
            }
        } else {
            guard let defaultLibrary = device.makeDefaultLibrary() else {
                fatalError("Failed to create default shader library")
            }
            library = defaultLibrary
            Log.info("Default shader library loaded")
        }

        self.shaderLibrary = library
    }
}

