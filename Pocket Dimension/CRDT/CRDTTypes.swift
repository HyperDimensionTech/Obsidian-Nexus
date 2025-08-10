import Foundation
import UIKit

// MARK: - Device Identification

/// Unique identifier for each device/replica in the system
public struct DeviceID: Hashable, Codable {
    public let uuid: String
    
    public init() {
        self.uuid = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
    
    public init(uuid: String) {
        self.uuid = uuid
    }
}

// MARK: - Vector Clock

/// Vector clock for tracking causality in distributed systems
public struct VectorClock: Codable, Hashable {
    private var clock: [DeviceID: UInt64]
    
    public init() {
        self.clock = [:]
    }
    
    public init(clock: [DeviceID: UInt64]) {
        self.clock = clock
    }
    
    /// Increment the clock for a specific device
    public mutating func increment(for deviceId: DeviceID) {
        clock[deviceId, default: 0] += 1
    }
    
    /// Get the timestamp for a specific device
    public func timestamp(for deviceId: DeviceID) -> UInt64 {
        return clock[deviceId, default: 0]
    }
    
    /// Merge two vector clocks (takes maximum of each device's timestamp)
    public func merged(with other: VectorClock) -> VectorClock {
        var result = self.clock
        
        for (deviceId, timestamp) in other.clock {
            result[deviceId] = max(result[deviceId, default: 0], timestamp)
        }
        
        return VectorClock(clock: result)
    }
    
    /// Check if this clock happened before another clock
    public func happensBefore(_ other: VectorClock) -> Bool {
        var foundStrictlyLess = false
        
        // Check all devices in both clocks
        let allDevices = Set(self.clock.keys).union(Set(other.clock.keys))
        
        for deviceId in allDevices {
            let thisTime = self.timestamp(for: deviceId)
            let otherTime = other.timestamp(for: deviceId)
            
            if thisTime > otherTime {
                return false // This clock is not before other
            } else if thisTime < otherTime {
                foundStrictlyLess = true
            }
        }
        
        return foundStrictlyLess
    }
    
    /// Check if two clocks are concurrent (neither happens before the other)
    public func isConcurrentWith(_ other: VectorClock) -> Bool {
        return !self.happensBefore(other) && !other.happensBefore(self) && self != other
    }
    
    /// Get the internal clock dictionary
    public var clocks: [DeviceID: UInt64] {
        return clock
    }
}

// MARK: - Last-Writer-Wins Register

/// CRDT for single values that resolves conflicts using Last-Writer-Wins with vector clocks
public struct LWWRegister<T: Codable>: Codable {
    public let value: T
    public let timestamp: VectorClock
    public let deviceId: DeviceID
    
    public init(value: T, timestamp: VectorClock, deviceId: DeviceID) {
        self.value = value
        self.timestamp = timestamp
        self.deviceId = deviceId
    }
    
    /// Create a new register with incremented timestamp
    public func updated(with newValue: T, deviceId: DeviceID) -> LWWRegister<T> {
        var newTimestamp = self.timestamp
        newTimestamp.increment(for: deviceId)
        
        return LWWRegister(
            value: newValue,
            timestamp: newTimestamp,
            deviceId: deviceId
        )
    }
    
    /// Merge two registers, keeping the one with the later timestamp
    public func merged(with other: LWWRegister<T>) -> LWWRegister<T> {
        // If other happened before this, keep this
        if other.timestamp.happensBefore(self.timestamp) {
            return self
        }
        // If this happened before other, keep other
        else if self.timestamp.happensBefore(other.timestamp) {
            return other
        }
        // If concurrent, use device ID as tiebreaker
        else {
            return self.deviceId.uuid < other.deviceId.uuid ? self : other
        }
    }
}

// MARK: - Observed-Remove Set

/// CRDT set that supports adding and removing elements without conflicts
public struct ORSet<T: Hashable & Codable>: Codable {
    private var added: [T: Set<VectorClock>]
    private var removed: [T: Set<VectorClock>]
    
    public init() {
        self.added = [:]
        self.removed = [:]
    }
    
    /// Add an element with a unique timestamp
    public mutating func add(_ element: T, timestamp: VectorClock) {
        added[element, default: Set()].insert(timestamp)
    }
    
    /// Remove an element (marks all current add timestamps as removed)
    public mutating func remove(_ element: T, timestamp: VectorClock) {
        // Remove all current add timestamps
        if let addTimestamps = added[element] {
            for addTimestamp in addTimestamps {
                removed[element, default: Set()].insert(addTimestamp)
            }
        }
        // Also add the remove timestamp
        removed[element, default: Set()].insert(timestamp)
    }
    
    /// Check if an element is in the set
    public func contains(_ element: T) -> Bool {
        guard let addTimestamps = added[element] else { return false }
        let removeTimestamps = removed[element, default: Set()]
        
        // Element is in the set if there's at least one add timestamp
        // that doesn't have a corresponding remove timestamp
        return !addTimestamps.isSubset(of: removeTimestamps)
    }
    
    /// Get all elements currently in the set
    public var elements: Set<T> {
        var result = Set<T>()
        
        for (element, addTimestamps) in added {
            let removeTimestamps = removed[element, default: Set()]
            if !addTimestamps.isSubset(of: removeTimestamps) {
                result.insert(element)
            }
        }
        
        return result
    }
    
    /// Merge with another ORSet
    public func merged(with other: ORSet<T>) -> ORSet<T> {
        var result = ORSet<T>()
        
        // Merge added sets
        let allElements = Set(self.added.keys).union(Set(other.added.keys))
        
        for element in allElements {
            let thisAdded = self.added[element, default: Set()]
            let otherAdded = other.added[element, default: Set()]
            result.added[element] = thisAdded.union(otherAdded)
        }
        
        // Merge removed sets
        let allRemovedElements = Set(self.removed.keys).union(Set(other.removed.keys))
        
        for element in allRemovedElements {
            let thisRemoved = self.removed[element, default: Set()]
            let otherRemoved = other.removed[element, default: Set()]
            result.removed[element] = thisRemoved.union(otherRemoved)
        }
        
        return result
    }
}

// MARK: - CRDT Operation

/// Represents a CRDT operation that can be applied to replicas
public protocol CRDTOperation: Codable {
    var timestamp: VectorClock { get }
    var deviceId: DeviceID { get }
    
    func apply<T: CRDTReplica>(to replica: inout T)
}

// MARK: - CRDT Replica

/// Protocol for objects that can be replicated using CRDTs
public protocol CRDTReplica {
    var vectorClock: VectorClock { get set }
    var deviceId: DeviceID { get }
    
    mutating func merge(with other: Self)
    mutating func apply(operation: CRDTOperation)
}

// MARK: - CRDT ISBN Mapping

/// CRDT representation of an ISBN mapping
public struct CRDTISBNMapping: CRDTReplica, Codable {
    public let incorrectISBN: String // This is the unique identifier
    public var correctGoogleBooksID: LWWRegister<String>
    public var title: LWWRegister<String>
    public var isReprint: LWWRegister<Bool>
    public var dateAdded: LWWRegister<Date>
    
    public var vectorClock: VectorClock
    public var deviceId: DeviceID
    public var isDeleted: Bool = false
    
    public init(
        incorrectISBN: String,
        correctGoogleBooksID: String,
        title: String,
        isReprint: Bool,
        dateAdded: Date,
        vectorClock: VectorClock,
        deviceId: DeviceID
    ) {
        self.incorrectISBN = incorrectISBN
        self.correctGoogleBooksID = LWWRegister(value: correctGoogleBooksID, timestamp: vectorClock, deviceId: deviceId)
        self.title = LWWRegister(value: title, timestamp: vectorClock, deviceId: deviceId)
        self.isReprint = LWWRegister(value: isReprint, timestamp: vectorClock, deviceId: deviceId)
        self.dateAdded = LWWRegister(value: dateAdded, timestamp: vectorClock, deviceId: deviceId)
        self.vectorClock = vectorClock
        self.deviceId = deviceId
    }
    
    /// Convert to domain model
    public func toDomainModel() -> ISBNMapping {
        return ISBNMapping(
            incorrectISBN: incorrectISBN,
            correctGoogleBooksID: correctGoogleBooksID.value,
            title: title.value,
            isReprint: isReprint.value,
            dateAdded: dateAdded.value
        )
    }
    
    public mutating func merge(with other: CRDTISBNMapping) {
        guard self.incorrectISBN == other.incorrectISBN else { return }
        
        self.correctGoogleBooksID = self.correctGoogleBooksID.merged(with: other.correctGoogleBooksID)
        self.title = self.title.merged(with: other.title)
        self.isReprint = self.isReprint.merged(with: other.isReprint)
        self.dateAdded = self.dateAdded.merged(with: other.dateAdded)
        
        self.vectorClock = self.vectorClock.merged(with: other.vectorClock)
        
        // Merge deletion state (if either is deleted, the merged result is deleted)
        self.isDeleted = self.isDeleted || other.isDeleted
    }
    
    public mutating func apply(operation: CRDTOperation) {
        // Generic operation application - specific operations would be handled in the repository
        self.vectorClock = self.vectorClock.merged(with: operation.timestamp)
    }
} 