import Combine
import Foundation
import UIKit

enum DiagnosticOutcome: String, Codable, Equatable {
    case success
    case successWithConflicts
    case cancelled
    case timeout
    case vaultAccessFailure
    case configurationFailure
    case engineFailure
}

struct DiagnosticStatusSummary: Codable, Equatable {
    let peerConnected: Bool
    let folderState: String
    let localCompletionPct: Double
    let remoteCompletionPct: Double
    let needItems: Int
    let needDeletes: Int
    let remoteNeedItems: Int
    let remoteNeedDeletes: Int

    init(status: FolderSyncStatus) {
        peerConnected = status.peerConnected
        folderState = Self.normalizedFolderState(status.folderState)
        localCompletionPct = status.localCompletionPct
        remoteCompletionPct = status.remoteCompletionPct
        needItems = status.needItems
        needDeletes = status.needDeletes
        remoteNeedItems = status.remoteNeedItems
        remoteNeedDeletes = status.remoteNeedDeletes
    }

    init(summary: DiagnosticStatusSummary) {
        peerConnected = summary.peerConnected
        folderState = Self.normalizedFolderState(summary.folderState)
        localCompletionPct = summary.localCompletionPct
        remoteCompletionPct = summary.remoteCompletionPct
        needItems = summary.needItems
        needDeletes = summary.needDeletes
        remoteNeedItems = summary.remoteNeedItems
        remoteNeedDeletes = summary.remoteNeedDeletes
    }

    private static func normalizedFolderState(_ value: String) -> String {
        switch value.lowercased() {
        case "idle", "scanning", "scan-waiting", "sync-waiting", "sync-preparing",
             "syncing", "clean-waiting", "cleaning", "error", "unknown":
            return value.lowercased()
        default:
            return "unknown"
        }
    }
}

struct DiagnosticEvent: Codable, Equatable {
    let timestamp: Date
    let phase: String
    let outcome: DiagnosticOutcome?
    let status: DiagnosticStatusSummary?
}

private struct DiagnosticEventEnvelope: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let events: [DiagnosticEvent]
}

struct DiagnosticEventStore {
    private let directory: URL
    private let fileManager: FileManager
    private let maximumEvents: Int

    init(
        directory: URL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("VaultSync", isDirectory: true),
        fileManager: FileManager = .default,
        maximumEvents: Int = 200
    ) {
        self.directory = directory
        self.fileManager = fileManager
        self.maximumEvents = max(1, maximumEvents)
    }

    var eventsURL: URL {
        directory.appendingPathComponent("diagnostic-events.json", isDirectory: false)
    }

    func load() throws -> [DiagnosticEvent] {
        guard fileManager.fileExists(atPath: eventsURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(
            DiagnosticEventEnvelope.self,
            from: Data(contentsOf: eventsURL)
        )
        guard envelope.schemaVersion == DiagnosticEventEnvelope.currentSchemaVersion else {
            return []
        }
        return Array(envelope.events.suffix(maximumEvents))
    }

    func save(_ events: [DiagnosticEvent]) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        let envelope = DiagnosticEventEnvelope(
            schemaVersion: DiagnosticEventEnvelope.currentSchemaVersion,
            events: Array(events.suffix(maximumEvents))
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        try data.write(
            to: eventsURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}

@MainActor
protocol DiagnosticsRecording: AnyObject {
    var events: [DiagnosticEvent] { get }
    func record(
        phase: SyncSessionPhase,
        status: FolderSyncStatus?,
        outcome: DiagnosticOutcome?
    )
}

@MainActor
final class NoOpDiagnosticsRecorder: DiagnosticsRecording {
    var events: [DiagnosticEvent] { [] }

    func record(
        phase: SyncSessionPhase,
        status: FolderSyncStatus?,
        outcome: DiagnosticOutcome?
    ) {}
}

@MainActor
final class DiagnosticsRecorder: ObservableObject, DiagnosticsRecording {
    @Published private(set) var events: [DiagnosticEvent]

    private let store: DiagnosticEventStore
    private let now: () -> Date

    init(
        store: DiagnosticEventStore = DiagnosticEventStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.now = now
        events = (try? store.load()) ?? []
    }

    func record(
        phase: SyncSessionPhase,
        status: FolderSyncStatus?,
        outcome: DiagnosticOutcome? = nil
    ) {
        events.append(
            DiagnosticEvent(
                timestamp: now(),
                phase: phase.rawValue,
                outcome: outcome,
                status: status.map(DiagnosticStatusSummary.init)
            )
        )
        events = Array(events.suffix(200))
        do {
            try store.save(events)
            events = try store.load()
        } catch {
            // Diagnostics must never interfere with a sync session.
        }
    }
}

struct DiagnosticsEnvironment: Codable, Equatable {
    let appVersion: String
    let appBuild: String
    let operatingSystem: String
    let deviceClass: String

    static var current: DiagnosticsEnvironment {
        DiagnosticsEnvironment(
            appVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown",
            appBuild: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? "unknown",
            operatingSystem: UIDevice.current.systemName + " " + UIDevice.current.systemVersion,
            deviceClass: UIDevice.current.model
        )
    }
}

struct DiagnosticsReport: Codable, Equatable {
    struct ConfigurationSummary: Codable, Equatable {
        let vaultSelected: Bool
        let peerConfigured: Bool
        let folderConfigured: Bool
        let addressMode: String
    }

    struct SessionSummary: Codable, Equatable {
        let phase: String
        let engineState: String
        let conflictCount: Int
        let status: DiagnosticStatusSummary?
    }

    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let environment: DiagnosticsEnvironment
    let configuration: ConfigurationSummary
    let session: SessionSummary
    let recentEvents: [DiagnosticEvent]
}

enum DiagnosticsReportBuilder {
    static func makeData(
        profile: SyncProfile?,
        vaultSelected: Bool,
        engineState: String,
        phase: SyncSessionPhase,
        status: FolderSyncStatus?,
        conflictCount: Int,
        events: [DiagnosticEvent],
        environment: DiagnosticsEnvironment = .current,
        generatedAt: Date = Date()
    ) throws -> Data {
        let addressMode: String
        if let profile {
            addressMode = profile.addresses.allSatisfy {
                $0.caseInsensitiveCompare("dynamic") == .orderedSame
            } ? "dynamic" : "custom"
        } else {
            addressMode = "notConfigured"
        }

        let report = DiagnosticsReport(
            schemaVersion: DiagnosticsReport.currentSchemaVersion,
            generatedAt: generatedAt,
            environment: environment,
            configuration: .init(
                vaultSelected: vaultSelected,
                peerConfigured: profile != nil,
                folderConfigured: profile != nil,
                addressMode: addressMode
            ),
            session: .init(
                phase: phase.rawValue,
                engineState: normalizedEngineState(engineState),
                conflictCount: conflictCount,
                status: status.map(DiagnosticStatusSummary.init)
            ),
            recentEvents: Array(events.suffix(200)).map(redactedEvent)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }

    private static func normalizedEngineState(_ value: String) -> String {
        switch value.lowercased() {
        case "idle", "starting", "running", "stopping", "stopped", "failed":
            return value.lowercased()
        default:
            return "unknown"
        }
    }

    private static func redactedEvent(_ event: DiagnosticEvent) -> DiagnosticEvent {
        let phase = SyncSessionPhase(rawValue: event.phase)?.rawValue ?? "unknown"
        return DiagnosticEvent(
            timestamp: event.timestamp,
            phase: phase,
            outcome: event.outcome,
            status: event.status.map(DiagnosticStatusSummary.init(summary:))
        )
    }
}

struct DiagnosticsExportWriter {
    private let directory: URL
    private let fileManager: FileManager

    init(
        directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VaultSync-Diagnostics", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func write(_ data: Data) throws -> URL {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        let url = directory.appendingPathComponent(
            "vault-sync-diagnostics.json",
            isDirectory: false
        )
        try data.write(
            to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
        return url
    }
}
