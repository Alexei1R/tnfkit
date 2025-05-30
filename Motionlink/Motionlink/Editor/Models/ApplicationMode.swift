// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation
import SwiftUI

protocol ModeLayerView: View {
    static var mode: ApplicationMode { get }
    static var title: String { get }
}

enum ApplicationMode: String, CaseIterable, Identifiable {
    case object = "Obj"
    case record = "Record"
    case scan = "Scan"
    case bone = "Bone"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .object:
            return "cube.fill"
        case .record:
            return "record.circle"
        case .scan:
            return "compass.drawing"
        case .bone:
            return "skew"
        }
    }

    var title: String {
        switch self {
        case .object:
            return "Objects"
        case .record:
            return "Record"
        case .scan:
            return "Scan"
        case .bone:
            return "Bone"
        }
    }

    // Get the view for this mode
    @ViewBuilder
    func createView() -> some View {
        switch self {
        case .object:
            ObjectLayerView()
        case .record:
            RecordLayerView()
        case .bone:
            BoneAssignmentView()
        case .scan:
            VStack { Text("Coming soon!") }
        }
    }
}
