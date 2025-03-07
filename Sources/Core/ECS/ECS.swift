// Copyright (c) 2025 The Noughy Fox
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Foundation

// NOTE: Core entity identifier
public struct Entity: Hashable {
    public let id: UInt64

    private init(id: UInt64) {
        self.id = id
    }

    @inline(__always)
    public static func generate() -> Entity {
        let uuid = UUID().uuid
        let id = UInt64(uuid.0) ^ UInt64(uuid.1) ^ UInt64(uuid.2) ^ UInt64(uuid.3)
        return Entity(id: id)
    }
}

// NOTE: Base component protocol
public protocol Component: Any {}

// NOTE: Internal storage for components
private final class ComponentStorage {
    private var components: [Int: Any]

    init(capacity: Int = 1000) {
        self.components = Dictionary(minimumCapacity: capacity)
    }

    @inline(__always)
    func insert<T: Component>(_ component: T, for entity: Entity) {
        components[entity.hashValue] = component
    }

    @inline(__always)
    func get<T: Component>(for entity: Entity) -> T? {
        return components[entity.hashValue] as? T
    }

    @inline(__always)
    func remove(for entity: Entity) {
        components.removeValue(forKey: entity.hashValue)
    }

    @inline(__always)
    func contains(_ entity: Entity) -> Bool {
        return components[entity.hashValue] != nil
    }

    func clear() {
        components.removeAll(keepingCapacity: true)
    }
}

// NOTE: Main ECS registry
public final class Registry {
    private var componentStorages: [ObjectIdentifier: ComponentStorage]
    public var entities: Set<Entity>

    public init(capacity: Int = 1000) {
        self.componentStorages = Dictionary(minimumCapacity: capacity)
        self.entities = Set<Entity>(minimumCapacity: capacity)
    }

    @discardableResult
    @inline(__always)
    public func createEntity(with components: Component...) -> Entity {
        let entity = Entity.generate()
        entities.insert(entity)
        for component in components {
            addComponent(component, to: entity)
        }
        return entity
    }

    @inline(__always)
    public func destroyEntity(_ entity: Entity) {
        entities.remove(entity)
        componentStorages.values.forEach { $0.remove(for: entity) }
    }

    @discardableResult
    @inline(__always)
    public func addComponent<T: Component>(_ component: T, to entity: Entity) -> T {
        let typeId = ObjectIdentifier(T.self)
        if componentStorages[typeId] == nil {
            componentStorages[typeId] = ComponentStorage()
        }
        componentStorages[typeId]?.insert(component, for: entity)
        return component
    }

    @inline(__always)
    public func getComponent<T: Component>(for entity: Entity) -> T? {
        let typeId = ObjectIdentifier(T.self)
        return componentStorages[typeId]?.get(for: entity)
    }

    @inline(__always)
    public func removeComponent<T: Component>(type: T.Type, from entity: Entity) {
        let typeId = ObjectIdentifier(T.self)
        componentStorages[typeId]?.remove(for: entity)
    }

    @inline(__always)
    public func hasComponent<T: Component>(type: T.Type, entity: Entity) -> Bool {
        let typeId = ObjectIdentifier(T.self)
        return componentStorages[typeId]?.contains(entity) ?? false
    }

    // NOTE: EntitySelection system for querying entities
    public struct EntitySelection<Components> {
        private let registry: Registry
        private let requiredComponentTypes: [ObjectIdentifier]
        private var cachedEntities: [Entity]

        fileprivate init(registry: Registry, componentTypes: [ObjectIdentifier]) {
            self.registry = registry
            self.requiredComponentTypes = componentTypes
            self.cachedEntities = []
            self.updateCache()
        }

        private mutating func updateCache() {
            cachedEntities = Array(registry.entities).filter { entity in
                requiredComponentTypes.allSatisfy { typeId in
                    registry.componentStorages[typeId]?.contains(entity) ?? false
                }
            }
        }

        public mutating func forEach(_ body: (Entity) -> Void) {
            updateCache()
            cachedEntities.forEach(body)
        }

        public mutating func map<T>(_ transform: (Entity) -> T) -> [T] {
            updateCache()
            var result = [T]()
            result.reserveCapacity(cachedEntities.count)
            return cachedEntities.map(transform)
        }

        public mutating func filter(_ isIncluded: (Entity) -> Bool) -> [Entity] {
            updateCache()
            var result = [Entity]()
            result.reserveCapacity(cachedEntities.count)
            return cachedEntities.filter(isIncluded)
        }
    }

    @inline(__always)
    public func selection<T1: Component>(requiring component1: T1.Type) -> EntitySelection<(T1.Type)> {
        return EntitySelection(registry: self, componentTypes: [ObjectIdentifier(T1.self)])
    }

    @inline(__always)
    public func selection<T1: Component, T2: Component>(
        requiring component1: T1.Type,
        _ component2: T2.Type
    ) -> EntitySelection<(T1.Type, T2.Type)> {
        return EntitySelection(
            registry: self,
            componentTypes: [
                ObjectIdentifier(T1.self),
                ObjectIdentifier(T2.self),
            ])
    }

    @inline(__always)
    public func selection<T1: Component, T2: Component, T3: Component>(
        requiring component1: T1.Type,
        _ component2: T2.Type,
        _ component3: T3.Type
    ) -> EntitySelection<(T1.Type, T2.Type, T3.Type)> {
        return EntitySelection(
            registry: self,
            componentTypes: [
                ObjectIdentifier(T1.self),
                ObjectIdentifier(T2.self),
                ObjectIdentifier(T3.self),
            ])
    }

    public func clear() {
        entities.removeAll(keepingCapacity: true)
        componentStorages.values.forEach { $0.clear() }
    }

    public var entityCount: Int {
        entities.count
    }
}
