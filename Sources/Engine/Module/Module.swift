// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation

public protocol Module {
    func start()
    func stop()
    func update(dt: Float)
}

extension Module {
    public func start() {}
    public func stop() {}
    public func update(dt: Float) {}
}

public final class ModuleStack {
    private var modules: [Module] = []

    public init() {}

    deinit {
        modules.forEach { $0.stop() }
    }

    public func addModule(_ module: Module) {
        modules.append(module)
        module.start()
    }

    public func removeModule(_ module: Module) {
        guard let index = modules.firstIndex(where: { $0 as AnyObject === module as AnyObject })
        else { return }

        module.stop()
        modules.remove(at: index)
    }

    public func updateAll(dt: Float) {
        modules.forEach { $0.update(dt: dt) }
    }
}
