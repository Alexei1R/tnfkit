// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation

public class Handle: Hashable, @unchecked Sendable {
    public let id: UUID

    public init() {
        self.id = UUID()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Handle, rhs: Handle) -> Bool {
        return lhs.id == rhs.id
    }

    public var description: String {
        return "Handle(\(id.uuidString))"
    }

    public var debugDescription: String {
        return description
    }
}
