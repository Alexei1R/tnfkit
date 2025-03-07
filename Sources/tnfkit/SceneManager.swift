// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core

public final class SceneManager: @unchecked Sendable {
    public static let shared = SceneManager()
    private var _scene: Scene?
    private init() {}

    public var scene: Scene {
        if _scene == nil {
            _scene = Scene()
        }
        return _scene!
    }

    public var hasScene: Bool {
        return _scene != nil
    }
}
