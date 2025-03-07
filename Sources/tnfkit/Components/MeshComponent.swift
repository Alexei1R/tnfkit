// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Metal

public class MeshComponent: Component {
    public let name: String
    public var isInitialized: Bool = false

    public init(name: String, fileExtension: String = "usdc") {
        self.name = name
    }

}

public class TransformComponent: Component {
    public var transform: mat4f = mat4f.identity

    public init(transform: mat4f) {
        self.transform = transform
    }

}
