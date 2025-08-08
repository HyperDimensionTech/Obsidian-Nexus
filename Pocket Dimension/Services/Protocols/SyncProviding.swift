import Foundation
import Combine

public protocol SyncProviding {
    var providerName: String { get }
    var isConnected: Bool { get }
    var connectionStatusPublisher: AnyPublisher<CloudConnectionStatus, Never> { get }
    func connect() async throws
    func disconnect() async
    func pushEvents(_ events: [CloudEvent]) async throws -> CloudSyncResult
    func pullEvents(since timestamp: Date?, limit: Int?) async throws -> CloudEventBatch
}


