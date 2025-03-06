// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import MetalKit

public class Device: @unchecked Sendable {
    public static let shared = Device()
    public let device: MTLDevice

    private init?() {
        //NOTE: Create a singleton device
        //TODO If the platform has more than one device make sure to select the best one
        guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        self.device = mtlDevice
        Log.info("Metal device created \(device.name)")

    }
}
