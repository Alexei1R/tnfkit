// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import Metal

//NOTE: Errors
enum ShaderError: Error {
    case functionNotFound(String)
    case libraryCreationFailed
    case invalidHandle
}

enum ShaderType {
    case vertex
    case fragment
    case compute
}

struct ShaderElement {
    let type: ShaderType
    let name: String
}

public struct ShaderLayout {
    let elements: [ShaderElement]

    init(elements: [ShaderElement]) {
        self.elements = elements
    }
}
